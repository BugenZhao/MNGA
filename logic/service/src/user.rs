use std::collections::HashMap;

use crate::{
    auth,
    error::{ServiceError, ServiceResult},
    fetch::fetch_json_value,
    utils::{extract_kv, json_bool, json_i64, json_string, json_u32, json_u64},
};
use dashmap::DashMap;
use lazy_static::lazy_static;
use protos::{
    DataModel::{
        FollowActivity, FollowActivity_Type, FollowActivity_oneof__post, LightPost, PostId, Topic,
        User, UserName,
    },
    Service::{
        FollowActivityListRequest, FollowActivityListResponse, FollowUserListRequest,
        FollowUserListResponse, FollowUserModifyRequest, FollowUserModifyRequest_Operation,
        FollowUserModifyResponse, RemoteUserRequest, RemoteUserResponse,
        RemoteUserResponse_oneof__user, UserSignatureUpdateRequest, UserSignatureUpdateResponse,
    },
};
use serde_json::Value;
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

pub(crate) fn extract_user_json(value: &Value, remote: bool) -> Option<User> {
    static MUTE_BUFF: &str = "105";

    let raw_signature = json_string(value, "signature")
        .or_else(|| json_string(value, "sign"))
        .unwrap_or_default();
    let name = extract_user_name(json_string(value, "username")?);
    let mute = json_bool(value, "mute").unwrap_or_else(|| {
        json_string(value, "buffs").is_some_and(|buffs| buffs.contains(MUTE_BUFF))
    });

    Some(User {
        id: json_string(value, "uid")?,
        name: Some(name).into(),
        avatar_url: json_string(value, "avatar").unwrap_or_default(),
        reg_date: json_u64(value, "regdate").unwrap_or_default(),
        post_num: json_u32(value, "postnum")
            .or_else(|| json_u32(value, "posts"))
            .unwrap_or_default(),
        fame: json_i64(value, "fame")
            .or_else(|| json_i64(value, "rvrc"))
            .unwrap_or_default(),
        signature: Some(text::parse_content(&raw_signature)).into(),
        mute,
        ip_location: json_string(value, "ipLoc").unwrap_or_default(),
        remote,
        followed: json_i64(value, "follow").unwrap_or_default() == 1,
        following_count: json_u32(value, "follow_num").unwrap_or_default(),
        follower_count: json_u32(value, "follow_by_num").unwrap_or_default(),
        ..Default::default()
    })
}

fn scalar_string(value: &Value) -> Option<String> {
    match value {
        Value::String(value) => Some(value.to_owned()),
        Value::Number(value) => Some(value.to_string()),
        _ => None,
    }
}

fn scalar_u32(value: &Value) -> Option<u32> {
    value
        .as_u64()
        .and_then(|value| value.try_into().ok())
        .or_else(|| value.as_str()?.parse().ok())
}

fn indexed(value: &Value, index: usize) -> Option<&Value> {
    value
        .as_array()
        .and_then(|values| values.get(index))
        .or_else(|| value.get(index.to_string()))
}

fn records(value: &Value) -> Vec<&Value> {
    match value {
        Value::Array(values) => values.iter().collect(),
        Value::Object(values) => {
            let mut values = values.iter().collect::<Vec<_>>();
            values.sort_by_key(|(key, _)| key.parse::<u64>().unwrap_or(u64::MAX));
            values.into_iter().map(|(_, value)| value).collect()
        }
        _ => Vec::new(),
    }
}

fn extract_follow_user(value: &Value) -> Option<User> {
    let id = json_string(value, "uid")?;
    Some(User {
        id,
        name: Some(extract_user_name(
            json_string(value, "username").unwrap_or_default(),
        ))
        .into(),
        avatar_url: json_string(value, "avatar").unwrap_or_default(),
        remote: false,
        followed: true,
        ..Default::default()
    })
}

fn extract_follow_users(value: &Value) -> Vec<User> {
    indexed(value, 0)
        .map(records)
        .unwrap_or_default()
        .into_iter()
        .filter_map(extract_follow_user)
        .collect()
}

fn extract_follow_topic(value: &Value, user: &User) -> Topic {
    let fid = json_string(value, "fid").unwrap_or_default();
    Topic {
        id: json_string(value, "tid").unwrap_or_default(),
        subject: Some(text::parse_subject(
            &json_string(value, "subject").unwrap_or_default(),
        ))
        .into(),
        author_id: user.id.to_owned(),
        author_name: Some(user.name.clone().unwrap_or_default()).into(),
        post_date: json_u64(value, "postdate").unwrap_or_default(),
        last_post_date: json_u64(value, "lastpost").unwrap_or_default(),
        replies_num: json_u32(value, "replies").unwrap_or_default(),
        fid,
        ..Default::default()
    }
}

pub async fn modify_follow_user(
    request: FollowUserModifyRequest,
) -> ServiceResult<FollowUserModifyResponse> {
    let followed = request.get_operation() == FollowUserModifyRequest_Operation::ADD;
    let follow_type = if followed { "1" } else { "8" };

    let _value = fetch_json_value(
        "nuke.php",
        vec![("__lib", "follow_v2"), ("__act", "follow")],
        vec![("id", request.get_user_id()), ("type", follow_type)],
    )
    .await?;

    UserController::get().invalidate_user(request.get_user_id());
    Ok(FollowUserModifyResponse {
        followed,
        ..Default::default()
    })
}

pub async fn get_follow_user_list(
    request: FollowUserListRequest,
) -> ServiceResult<FollowUserListResponse> {
    let page = request.page.max(1);
    let value = fetch_json_value(
        "nuke.php",
        vec![("__lib", "follow_v2"), ("__act", "get_follow")],
        vec![("page", &page.to_string())],
    )
    .await?;

    let users = extract_follow_users(&value)
        .into_iter()
        .inspect(|user| UserController::get().update_user(user.to_owned()))
        .collect::<Vec<_>>();
    let pages = if users.is_empty() { page } else { page + 1 };

    Ok(FollowUserListResponse {
        users: users.into(),
        pages,
        ..Default::default()
    })
}

pub async fn get_follow_activity_list(
    request: FollowActivityListRequest,
) -> ServiceResult<FollowActivityListResponse> {
    let page = request.page.max(1);
    let value = fetch_json_value(
        "nuke.php",
        vec![("__lib", "follow_v2"), ("__act", "get_push_list")],
        vec![("page", &page.to_string())],
    )
    .await?;

    let events = indexed(&value, 0).map(records).unwrap_or_default();
    let users = indexed(&value, 1).unwrap_or(&Value::Null);
    let topics = indexed(&value, 4).unwrap_or(&Value::Null);
    let pages = indexed(&value, 2)
        .and_then(scalar_u32)
        .unwrap_or_else(|| if events.is_empty() { page } else { page + 1 });

    let activities = events
        .into_iter()
        .filter_map(|event| {
            let id = indexed(event, 0).and_then(scalar_string)?;
            let activity_type = indexed(event, 1).and_then(scalar_u32).unwrap_or_default();
            let user_id = indexed(event, 2).and_then(scalar_string)?;
            let topic_id = indexed(event, 3).and_then(scalar_string)?;
            let post_id = indexed(event, 4)
                .and_then(scalar_string)
                .unwrap_or_default();

            let user_value = users.get(&user_id)?;
            let user =
                extract_follow_user(user_value).or_else(|| extract_user_json(user_value, false))?;
            UserController::get().update_user(user.to_owned());

            let topic_value = topics.get(&topic_id)?;
            let mut topic = extract_follow_topic(topic_value, &user);
            if topic.id.is_empty() {
                topic.id.clone_from(&topic_id);
            }

            let mut activity = FollowActivity {
                id,
                field_type: if activity_type == 2 {
                    FollowActivity_Type::REPLY
                } else {
                    FollowActivity_Type::TOPIC
                },
                user: Some(user.clone()).into(),
                topic: Some(topic).into(),
                ..Default::default()
            };

            if activity.field_type == FollowActivity_Type::REPLY {
                let reply_key = format!("{topic_id}_{post_id}");
                let reply_value = topics.get(&reply_key).unwrap_or(topic_value);
                activity._post = Some(FollowActivity_oneof__post::post(LightPost {
                    id: Some(PostId {
                        pid: post_id,
                        tid: topic_id,
                        ..Default::default()
                    })
                    .into(),
                    author_id: user.id,
                    content: Some(text::parse_content(
                        &json_string(reply_value, "content").unwrap_or_default(),
                    ))
                    .into(),
                    post_date: json_u64(reply_value, "postdate").unwrap_or_default(),
                    ..Default::default()
                }));
            }
            Some(activity)
        })
        .collect::<Vec<_>>();

    Ok(FollowActivityListResponse {
        activities: activities.into(),
        pages,
        ..Default::default()
    })
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

    let value = fetch_json_value(
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

    let mut user = value.get("0").and_then(|v| extract_user_json(v, true));

    if let Some(user) = &mut user
        && user.avatar_url.is_empty()
    {
        let avatar_url = {
            let avatar_value = fetch_json_value(
                "nuke.php",
                // Always query avatar with uid instead of user name.
                vec![("__lib", "ucp"), ("__act", "get_avatar"), ("uid", &user.id)],
                vec![],
            )
            .await?;
            json_string(&avatar_value, "0").unwrap_or_default()
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
    let escaped_signature = text::escape_for_submit(request.get_signature());
    if uid.is_empty() {
        return Err(ServiceError::MngaInternal("Not logged in".to_owned()));
    }

    let _value = fetch_json_value(
        "nuke.php",
        vec![
            ("__lib", "set_sign"),
            ("__act", "set"),
            ("uid", &uid),
            ("sign", escaped_signature.as_str()),
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
    use crate::error::ServiceError;

    use super::*;

    #[ignore = "manual: requires network or mutable external state"]
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

    #[ignore = "manual: requires network or mutable external state"]
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

    #[ignore = "manual: requires network or mutable external state"]
    #[tokio::test]
    async fn test_remote_user_not_found_error() -> ServiceResult<()> {
        let err = get_remote_user(RemoteUserRequest {
            user_id: "999999999999999999".to_owned(),
            ..Default::default()
        })
        .await
        .unwrap_err();

        match err {
            ServiceError::Nga(e) => {
                assert_eq!(e.code, "?");
                assert_eq!(e.info, "找不到用户");
            }
            other => panic!("unexpected error: {other:?}"),
        }

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

    #[test]
    fn test_extract_follow_users_from_wrapped_list() {
        let value = serde_json::json!([
            {
                "0": { "uid": "100", "username": "Alice", "avatar": "alice.png" },
                "1": { "uid": 200, "username": "Bob" }
            }
        ]);

        let users = extract_follow_users(&value);

        assert_eq!(users.len(), 2);
        assert_eq!(users[0].get_id(), "100");
        assert_eq!(users[0].get_name().get_normal(), "Alice");
        assert_eq!(users[1].get_id(), "200");
        assert_eq!(users[1].get_name().get_normal(), "Bob");
        assert!(users.iter().all(User::get_followed));
    }

    #[ignore = "manual: requires network or mutable external state"]
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
