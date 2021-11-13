use crate::{
    error::ServiceResult,
    fetch_package,
    post::extract_post_content,
    utils::{extract_kv, extract_node},
};
use dashmap::DashMap;
use lazy_static::lazy_static;
use protos::{
    DataModel::{User, UserName},
    Service::{RemoteUserRequest, RemoteUserResponse, RemoteUserResponse_oneof__user},
};
use sxd_xpath::nodeset::Node;

lazy_static! {
    static ref USER_CONTROLLER: UserController = Default::default();
}

#[derive(Default)]
pub struct UserController {
    map: DashMap<String, User>,
}

#[allow(dead_code)]
impl UserController {
    pub fn get<'a>() -> &'a Self {
        &USER_CONTROLLER
    }

    pub fn update_user(&self, user: User) {
        self.map.insert(user.id.to_owned(), user);
    }

    pub fn update_users(&self, users: Vec<User>) {
        users.into_iter().for_each(|u| self.update_user(u));
    }
}

impl std::ops::Deref for UserController {
    type Target = DashMap<String, User>;

    fn deref(&self) -> &Self::Target {
        &self.map
    }
}

pub fn extract_user_name(original_name: String) -> UserName {
    static PREFIX: &'static str = "#anony_";
    static PART_A: &'static str = "甲乙丙丁戊己庚辛壬癸子丑寅卯辰巳午未申酉戌亥";
    static PART_B: &'static str = "王李张刘陈杨黄吴赵周徐孙马朱胡林郭何高罗郑梁谢宋唐许邓冯韩曹曾彭萧蔡潘田董袁于余叶蒋杜苏魏程吕丁沈任姚卢傅钟姜崔谭廖范汪陆金石戴贾韦夏邱方侯邹熊孟秦白江阎薛尹段雷黎史龙陶贺顾毛郝龚邵万钱严赖覃洪武莫孔汤向常温康施文牛樊葛邢安齐易乔伍庞颜倪庄聂章鲁岳翟殷詹申欧耿关兰焦俞左柳甘祝包宁尚符舒阮柯纪梅童凌毕单季裴霍涂成苗谷盛曲翁冉骆蓝路游辛靳管柴蒙鲍华喻祁蒲房滕屈饶解牟艾尤阳时穆农司卓古吉缪简车项连芦麦褚娄窦戚岑景党宫费卜冷晏席卫米柏宗瞿桂全佟应臧闵苟邬边卞姬师和仇栾隋商刁沙荣巫寇桑郎甄丛仲虞敖巩明佘池查麻苑迟邝";

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

fn extract_user(node: Node) -> Option<User> {
    use super::macros::get;
    let map = extract_kv(node);

    let name = extract_user_name(get!(map, "username")?);

    let raw_signature = get!(map, "signature")
        .or_else(|| get!(map, "sign"))
        .unwrap_or_default();
    let signature = extract_post_content(raw_signature);

    let user = User {
        id: get!(map, "uid")?,
        name: Some(name).into(),
        avatar_url: get!(map, "avatar")?,
        reg_date: get!(map, "regdate", _)?,
        post_num: get!(map, "postnum", _).or_else(|| get!(map, "posts", _))?,
        fame: get!(map, "fame", _).or_else(|| get!(map, "rvrc", _))?,
        signature: Some(signature).into(),
        ..Default::default()
    };

    Some(user)
}

pub fn extract_user_and_cache(node: Node) -> Option<User> {
    let user = extract_user(node)?;
    UserController::get().update_user(user.clone());
    Some(user)
}

pub async fn get_remote_user(request: RemoteUserRequest) -> ServiceResult<RemoteUserResponse> {
    let user_id = request.get_user_id();
    if let Some(user) = UserController::get().get(user_id) {
        return Ok(RemoteUserResponse {
            _user: Some(RemoteUserResponse_oneof__user::user(user.to_owned())),
            ..Default::default()
        });
    }

    let package = fetch_package(
        "nuke.php",
        vec![
            ("__lib", "ucp"),
            ("__act", "get"),
            ("uid", &user_id),
            ("username", request.get_user_name()),
        ],
        vec![],
    )
    .await?;

    let user = extract_node(&package, "/root/data/item", extract_user_and_cache)?.flatten();

    Ok(RemoteUserResponse {
        _user: user.map(RemoteUserResponse_oneof__user::user),
        ..Default::default()
    })
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
}
