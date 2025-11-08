use std::collections::HashMap;

use crate::{
    auth,
    error::{ServiceError, ServiceResult},
    fetch_package,
    utils::{extract_kv, extract_node, extract_string},
};
use dashmap::DashMap;
use lazy_static::lazy_static;
use protos::{
    DataModel::{User, UserName},
    Service::{
        RemoteUserRequest, RemoteUserResponse, RemoteUserResponse_oneof__user,
        UserSignatureUpdateRequest, UserSignatureUpdateResponse,
    },
};
use sxd_xpath::nodeset::Node;

lazy_static! {
    static ref USER_CONTROLLER: UserController = Default::default();
}

pub fn attach_context_to_id(id: &str, context: &str) -> String {
    format!("{},{}", context, id)
}

#[derive(Default, Debug)]
pub struct UserController {
    map: DashMap<String, User>,
    anonymous: DashMap<String, HashMap<String, User>>,
}

impl UserController {
    pub fn get<'a>() -> &'a Self {
        &USER_CONTROLLER
    }

    pub fn update_user(&self, user: User) {
        self.map.insert(user.id.to_owned(), user);
    }

    pub fn invalidate_user(&self, id: &str) {
        self.map.remove(id);
    }

    pub fn add_anonymous_user(&self, mut user: User, context: &str) -> User {
        let mut e = self.anonymous.entry(context.to_owned()).or_default();
        let v = e.value_mut();
        let id = attach_context_to_id(&format!("-{}", v.len() + 1), context);
        user.set_id(id);
        v.insert(user.get_id().to_owned(), user.clone());
        user
    }

    pub fn get_by_id(&self, id: &str) -> Option<User> {
        if id.contains(',') {
            let context: String = id.chars().take_while(|c| *c != ',').collect();
            let map = self.anonymous.get(&context)?;
            let user = map.get(id)?;
            return Some(user.to_owned());
        }
        self.map.get(id).map(|u| u.to_owned()).or_else(|| {
            // may treat anony raw name as id
            let name = extract_user_name(id.to_owned());
            (name.get_anonymous() != "").then(|| User {
                id: id.to_owned(),
                name: Some(name).into(),
                ..Default::default()
            })
        })
    }
}

pub fn extract_user_name(original_name: String) -> UserName {
    static PREFIX: &str = "#anony_";
    static PART_A: &str = "甲乙丙丁戊己庚辛壬癸子丑寅卯辰巳午未申酉戌亥";
    static PART_B: &str = "王李张刘陈杨黄吴赵周徐孙马朱胡林郭何高罗郑梁谢宋唐许邓冯韩曹曾彭萧蔡潘田董袁于余叶蒋杜苏魏程吕丁沈任姚卢傅钟姜崔谭廖范汪陆金石戴贾韦夏邱方侯邹熊孟秦白江阎薛尹段雷黎史龙陶贺顾毛郝龚邵万钱严赖覃洪武莫孔汤向常温康施文牛樊葛邢安齐易乔伍庞颜倪庄聂章鲁岳翟殷詹申欧耿关兰焦俞左柳甘祝包宁尚符舒阮柯纪梅童凌毕单季裴霍涂成苗谷盛曲翁冉骆蓝路游辛靳管柴蒙鲍华喻祁蒲房滕屈饶解牟艾尤阳时穆农司卓古吉缪简车项连芦麦褚娄窦戚岑景党宫费卜冷晏席卫米柏宗瞿桂全佟应臧闵苟邬边卞姬师和仇栾隋商刁沙荣巫寇桑郎甄丛仲虞敖巩明佘池查麻苑迟邝";

    let mut user_name = UserName::default();
    user_name.set_normal(original_name);

    match user_name.get_normal().strip_prefix(PREFIX) {
        Some(code) if code.len() == 32 => {
            let mut i = 0;
            let mut anony = String::new();

            for j in 0..6 {
                let char = if j == 0 || j == 3 {
                    i32::from_str_radix(&code[i..(i + 1)], 16)
                        .map(|p| p.clamp(0, (PART_A.len() - 1) as i32) as usize)
                        .ok()
                        .and_then(|p| PART_A.chars().nth(p))
                } else {
                    i32::from_str_radix(&code[(i - 1)..(i + 1)], 16)
                        .map(|p| p.clamp(0, (PART_B.len() - 1) as i32) as usize)
                        .ok()
                        .and_then(|p| PART_B.chars().nth(p))
                };
                match char {
                    Some(char) => {
                        anony.push(char);
                        i += 2;
                    }
                    None => return user_name,
                }
            }

            user_name.set_anonymous(anony);
        }
        _ => {}
    };

    user_name
}

fn extract_user(node: Node, remote: bool) -> Option<User> {
    static MUTE_BUFF: &str = "105";

    use super::macros::get;
    let map = extract_kv(node);

    let name = extract_user_name(get!(map, "username")?);

    let raw_signature = get!(map, "signature")
        .or_else(|| get!(map, "sign"))
        .unwrap_or_default();
    let signature = text::parse_content(&raw_signature);

    let mute = get!(map, "buffs").unwrap_or_default().contains(MUTE_BUFF);

    let user = User {
        id: get!(map, "uid")?,
        name: Some(name).into(),
        avatar_url: get!(map, "avatar").unwrap_or_default(),
        reg_date: get!(map, "regdate", _).unwrap_or_default(),
        post_num: get!(map, "postnum", _)
            .or_else(|| get!(map, "posts", _))
            .unwrap_or_default(),
        fame: get!(map, "fame", _)
            .or_else(|| get!(map, "rvrc", _))
            .unwrap_or_default(),
        signature: Some(signature).into(),
        mute,
        ip_location: get!(map, "ipLoc").unwrap_or_default(),
        remote,
        ..Default::default()
    };

    Some(user)
}

fn cache_user(mut user: User, context: Option<&str>) -> User {
    let controller = UserController::get();
    match (user.get_name().get_anonymous() != "", context) {
        (true, Some(context)) => user = controller.add_anonymous_user(user.clone(), context),
        (true, None) => {}
        (false, _) => controller.update_user(user.clone()),
    }
    user
}

pub fn extract_local_user_and_cache(node: Node, context: Option<&str>) -> Option<User> {
    let user = extract_user(node, false)?;
    Some(cache_user(user, context))
}

pub async fn get_remote_user(request: RemoteUserRequest) -> ServiceResult<RemoteUserResponse> {
    let user_id = request.get_user_id();

    // Only return cached user if it's remote.
    if let Some(user) = UserController::get().get_by_id(user_id)
        && user.remote
    {
        return Ok(RemoteUserResponse {
            _user: Some(RemoteUserResponse_oneof__user::user(user)),
            ..Default::default()
        });
    }

    let mut user = {
        let package = fetch_package(
            "nuke.php",
            vec![
                ("__lib", "ucp"),
                ("__act", "get"),
                if user_id.is_empty() {
                    ("username", request.get_user_name())
                } else {
                    ("uid", user_id)
                },
            ],
            vec![],
        )
        .await?;
        extract_node(&package, "/root/data/item", |n| extract_user(n, true))?.flatten()
    };

    if let Some(user) = &mut user
        && user.avatar_url.is_empty()
    {
        let avatar_url = {
            let avatar_package = fetch_package(
                "nuke.php",
                // Always query avatar with uid instead of user name.
                vec![("__lib", "ucp"), ("__act", "get_avatar"), ("uid", &user.id)],
                vec![],
            )
            .await?;
            extract_string(&avatar_package, "/root/data/item").unwrap_or_default()
        };
        user.avatar_url = avatar_url;
    }
    user = user.map(|user| cache_user(user, None));

    Ok(RemoteUserResponse {
        _user: user.map(RemoteUserResponse_oneof__user::user),
        ..Default::default()
    })
}

pub async fn update_signature(
    request: UserSignatureUpdateRequest,
) -> ServiceResult<UserSignatureUpdateResponse> {
    let uid = auth::current_uid();
    if uid.is_empty() {
        return Err(ServiceError::MngaInternal("Not logged in".to_owned()));
    }

    let _package = fetch_package(
        "nuke.php",
        vec![
            ("__lib", "set_sign"),
            ("__act", "set"),
            ("uid", &uid),
            ("sign", request.get_signature()),
        ],
        vec![],
    )
    .await?;

    // Invalidate the user cache.
    UserController::get().invalidate_user(&uid);

    Ok(Default::default())
}

#[cfg(test)]
mod test {
    use super::*;

    #[tokio::test]
    async fn test_remote_user() -> ServiceResult<()> {
        let response = get_remote_user(RemoteUserRequest {
            user_id: "41417929".to_owned(),
            ..Default::default()
        })
        .await?;

        println!("response: {:?}", response);

        assert!(response.has_user());
        assert_eq!(response.get_user().get_name().get_normal(), "BugenZhao");

        Ok(())
    }

    #[tokio::test]
    async fn test_remote_user_name() -> ServiceResult<()> {
        let response = get_remote_user(RemoteUserRequest {
            user_name: "MNGA-Review".to_owned(),
            ..Default::default()
        })
        .await?;

        println!("response: {:?}", response);

        assert!(response.has_user());
        assert_eq!(response.get_user().get_id(), "63598535");

        Ok(())
    }

    #[test]
    fn test_anonymous_name() {
        assert_eq!(
            extract_user_name("#anony_1161b2b5b7c68764251be6c35de7287b".to_owned()).get_anonymous(),
            "乙谢冯丑万翟"
        );
        assert_eq!(
            extract_user_name("#anony_8cec9b35cf118bfdbde7e28d6df94143".to_owned()).get_anonymous(),
            "壬宫窦丁钱甄"
        );
        assert_eq!(
            extract_user_name("#anony_bad".to_owned()).get_anonymous(),
            ""
        );
    }

    #[test]
    fn test_anonymous_name_as_id() {
        let controller = UserController::get();
        let anony_name = "#anony_8cec9b35cf118bfdbde7e28d6df94143";
        let user = controller.get_by_id(anony_name).unwrap();
        assert_eq!(user.get_id(), anony_name);
        assert_eq!(user.get_name().get_normal(), anony_name);
        assert_eq!(user.get_name().get_anonymous(), "壬宫窦丁钱甄");
    }

    #[tokio::test]
    async fn test_update_signature() -> ServiceResult<()> {
        async fn get_signature() -> ServiceResult<String> {
            Ok(get_remote_user(RemoteUserRequest {
                user_id: auth::current_uid(),
                ..Default::default()
            })
            .await?
            .get_user()
            .get_signature()
            .get_raw()
            .to_string())
        }

        let original_sign = get_signature().await?;
        let new_sign = "测试签名 from logic test";

        let _response = update_signature(UserSignatureUpdateRequest {
            signature: new_sign.to_owned(),
            ..Default::default()
        })
        .await?;

        let new_current_sign = get_signature().await?;
        assert_eq!(new_current_sign, new_sign);

        // Revert the signature.
        let _response = update_signature(UserSignatureUpdateRequest {
            signature: original_sign.clone(),
            ..Default::default()
        })
        .await?;
        let reverted_sign = get_signature().await?;
        assert_eq!(reverted_sign, original_sign);

        Ok(())
    }
}
