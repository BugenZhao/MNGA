use protos::{
    DataModel::{ShortMessage, ShortMessagePost, UserName},
    Service::{
        ShortMessageDetailsRequest, ShortMessageDetailsResponse, ShortMessageListRequest,
        ShortMessageListResponse, ShortMessagePostRequest, ShortMessagePostResponse,
    },
    ToValue,
};
use serde_json::Value;

use crate::{
    error::ServiceResult,
    fetch::fetch_json_value,
    user::{UserController, extract_user_json, extract_user_name},
    utils::{json_string, json_u32, json_u64, json_value_to_string},
};

fn extract_all_users(raw: &str) -> (Vec<String>, Vec<UserName>) {
    raw.split('\t')
        .collect::<Vec<_>>()
        .chunks(2)
        .filter(|c| c.len() == 2)
        .map(|c| (c[0], c[1]))
        .filter(|(_id, name)| !name.is_empty())
        .map(|(id, name)| (id.to_owned(), extract_user_name(name.to_owned())))
        .unzip()
}

fn cache_local_user(user: &protos::DataModel::User) {
    if user.get_name().get_anonymous().is_empty() {
        UserController::get().update_user(user.clone());
    }
}

fn extract_short_msg_json(value: &Value) -> Option<ShortMessage> {
    let (ids, user_names) = json_string(value, "all_user")
        .map(|r| extract_all_users(&r))
        .unwrap_or_default();

    Some(ShortMessage {
        id: json_string(value, "mid")?,
        subject: json_string(value, "subject").unwrap_or_default(),
        from_id: json_string(value, "from")?,
        from_name: json_string(value, "from_username")?,
        post_date: json_u64(value, "time").unwrap_or_default(),
        last_post_date: json_u64(value, "last_modify").unwrap_or_default(),
        post_num: json_u32(value, "posts").unwrap_or_default(),
        ids: ids.into(),
        user_names: user_names.into(),
        ..Default::default()
    })
}

pub async fn get_short_msg_list(
    request: ShortMessageListRequest,
) -> ServiceResult<ShortMessageListResponse> {
    let value = fetch_json_value(
        "nuke.php",
        vec![
            ("__lib", "message"),
            ("__act", "message"),
            ("act", "list"),
            ("page", &request.page.to_string()),
        ],
        vec![],
    )
    .await?;

    let messages: Vec<_> = value
        .get("0")
        .and_then(Value::as_object)
        .map(|items| items.values().filter_map(extract_short_msg_json).collect())
        .unwrap_or_default();

    let has_next_page = json_string(&value, "nextPage").unwrap_or_default() != "";
    let pages = if has_next_page {
        u32::MAX
    } else {
        request.page
    };

    Ok(ShortMessageListResponse {
        messages: messages.into(),
        pages,
        ..Default::default()
    })
}

fn extract_short_msg_post_json(value: &Value) -> Option<ShortMessagePost> {
    let raw_content = json_string(value, "content")?;
    let content = text::parse_content(&raw_content);

    Some(ShortMessagePost {
        id: json_string(value, "id")?,
        author_id: json_string(value, "from").unwrap_or_default(),
        subject: json_string(value, "subject").unwrap_or_default(),
        content: Some(content).into(),
        post_date: json_u64(value, "time").unwrap_or_default(),
        ..Default::default()
    })
}

pub async fn get_short_msg_details(
    request: ShortMessageDetailsRequest,
) -> ServiceResult<ShortMessageDetailsResponse> {
    let value = fetch_json_value(
        "nuke.php",
        vec![
            ("__lib", "message"),
            ("__act", "message"),
            ("act", "read"),
            ("mid", request.get_id()),
            ("page", &request.page.to_string()),
        ],
        vec![],
    )
    .await?;

    let data = value.get("0").and_then(Value::as_object);

    let users: Vec<_> = data
        .and_then(|data| data.get("userInfo"))
        .and_then(Value::as_object)
        .map(|items| {
            items
                .values()
                .filter_map(|value| {
                    let user = extract_user_json(value, false)?;
                    cache_local_user(&user);
                    Some(user)
                })
                .collect()
        })
        .unwrap_or_default();

    let posts: Vec<_> = data
        .and_then(|data| data.get("allmsgs"))
        .and_then(Value::as_object)
        .map(|items| {
            items
                .values()
                .filter_map(extract_short_msg_post_json)
                .collect()
        })
        .unwrap_or_default();

    let has_next_page = data
        .and_then(|data| data.get("nextPage"))
        .and_then(json_value_to_string)
        .unwrap_or_default()
        != "";
    let pages = if has_next_page {
        u32::MAX
    } else {
        request.page
    };

    let _ = data
        .and_then(|data| data.get("allUsers"))
        .and_then(json_value_to_string)
        .map(|r| extract_all_users(&r))
        .unwrap_or_default();

    let response = ShortMessageDetailsResponse {
        posts: posts.into(),
        pages,
        users: users.into(),
        ..Default::default()
    };
    Ok(response)
}

pub async fn post_short_msg(
    request: ShortMessagePostRequest,
) -> ServiceResult<ShortMessagePostResponse> {
    let to = request.get_to().join(" ");
    let escaped_subject = text::escape_for_submit(request.get_subject());
    let escaped_content = text::escape_for_submit(request.get_content());

    let _value = fetch_json_value(
        "nuke.php",
        vec![
            ("__lib", "message"),
            ("__act", "message"),
            ("act", request.get_action().get_operation().to_value()),
            ("subject", escaped_subject.as_str()),
            ("content", escaped_content.as_str()),
            ("to", request.get_action().get_single_to()),
            ("to", to.as_str()),
            ("mid", request.get_action().get_mid()),
        ],
        vec![],
    )
    .await?;

    Ok(Default::default())
}

#[cfg(test)]
mod test {
    use protos::DataModel::{ShortMessagePostAction, ShortMessagePostAction_Operation};

    use super::*;

    #[ignore = "manual: requires network or mutable external state"]
    #[tokio::test]
    async fn test_get_short_msg_list() -> ServiceResult<()> {
        let response = get_short_msg_list(ShortMessageListRequest {
            page: 1,
            ..Default::default()
        })
        .await?;

        println!("response: {:?}", response);

        assert!(!response.get_messages().is_empty());

        Ok(())
    }

    #[ignore = "manual: requires network or mutable external state"]
    #[tokio::test]
    async fn test_get_short_msg_details() -> ServiceResult<()> {
        let list = get_short_msg_list(ShortMessageListRequest {
            page: 1,
            ..Default::default()
        })
        .await?;
        let mid = list
            .get_messages()
            .first()
            .map(|msg| msg.get_id().to_owned())
            .unwrap();

        let response = get_short_msg_details(ShortMessageDetailsRequest {
            id: mid,
            page: 1,
            ..Default::default()
        })
        .await?;

        println!("response: {:?}", response);

        assert!(!response.get_posts().is_empty());

        Ok(())
    }

    #[ignore = "manual: requires network or mutable external state"]
    #[tokio::test]
    async fn test_post_new_short_msg() -> ServiceResult<()> {
        let action = ShortMessagePostAction {
            operation: ShortMessagePostAction_Operation::NEW,
            ..Default::default()
        };

        let response = post_short_msg(ShortMessagePostRequest {
            action: Some(action).into(),
            content: "Test Content".to_owned(),
            subject: "Test Short Message from Logic Test".to_owned(),
            to: vec!["y-ricky".to_owned()].into(),
            ..Default::default()
        })
        .await?;

        println!("response: {:?}", response);

        Ok(())
    }

    #[ignore = "manual: requires network or mutable external state"]
    #[tokio::test]
    async fn test_reply_short_msg() -> ServiceResult<()> {
        let action = ShortMessagePostAction {
            operation: ShortMessagePostAction_Operation::REPLY,
            mid: "3549006".to_owned(),
            ..Default::default()
        };

        let response = post_short_msg(ShortMessagePostRequest {
            action: Some(action).into(),
            content: "Test Reply Content".to_owned(),
            subject: "Test Reply Short Message from Logic Test".to_owned(),
            ..Default::default()
        })
        .await?;

        println!("response: {:?}", response);

        Ok(())
    }
}
