use protos::{
    DataModel::{ShortMessage, ShortMessagePost},
    Service::{
        ShortMessageDetailsRequest, ShortMessageDetailsResponse, ShortMessageListRequest,
        ShortMessageListResponse, ShortMessagePostRequest, ShortMessagePostResponse,
    },
    ToValue,
};
use sxd_xpath::nodeset::Node;

use crate::{
    error::ServiceResult,
    fetch::fetch_package,
    post::extract_post_content,
    user::extract_user_and_cache,
    utils::{extract_kv, extract_nodes, extract_string},
};

fn extract_short_msg(node: Node) -> Option<ShortMessage> {
    use super::macros::get;
    let map = extract_kv(node);

    let short_msg = ShortMessage {
        id: get!(map, "mid")?,
        subject: get!(map, "subject").unwrap_or_default(),
        from_id: get!(map, "from")?,
        from_name: get!(map, "from_username")?,
        post_date: get!(map, "time", _).unwrap_or_default(),
        last_post_date: get!(map, "last_modify", _).unwrap_or_default(),
        post_num: get!(map, "posts", _).unwrap_or_default(),
        ..Default::default()
    };

    Some(short_msg)
}

pub async fn get_short_msg_list(
    request: ShortMessageListRequest,
) -> ServiceResult<ShortMessageListResponse> {
    let package = fetch_package(
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

    let messages = extract_nodes(&package, "/root/data/item/item", |ns| {
        ns.into_iter().filter_map(extract_short_msg).collect()
    })?;

    let has_next_page =
        extract_string(&package, "/root/data/item/nextPage").unwrap_or_default() != "";
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

fn extract_short_msg_post(node: Node) -> Option<ShortMessagePost> {
    use super::macros::get;
    let map = extract_kv(node);

    let raw_content = get!(map, "content")?;
    let content = extract_post_content(raw_content);

    let post = ShortMessagePost {
        id: get!(map, "id")?,
        author_id: get!(map, "from").unwrap_or_default(),
        subject: get!(map, "subject").unwrap_or_default(),
        content: Some(content).into(),
        post_date: get!(map, "time", _).unwrap_or_default(),
        ..Default::default()
    };

    Some(post)
}

pub async fn get_short_msg_details(
    request: ShortMessageDetailsRequest,
) -> ServiceResult<ShortMessageDetailsResponse> {
    let package = fetch_package(
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

    let _users = extract_nodes(&package, "/root/data/item/userInfo/item", |ns| {
        ns.into_iter().filter_map(extract_user_and_cache).collect()
    })?;

    let posts = extract_nodes(&package, "/root/data/item/item", |ns| {
        ns.into_iter().filter_map(extract_short_msg_post).collect()
    })?;

    let has_next_page =
        extract_string(&package, "/root/data/item/nextPage").unwrap_or_default() != "";
    let pages = if has_next_page {
        u32::MAX
    } else {
        request.page
    };

    let response = ShortMessageDetailsResponse {
        posts: posts.into(),
        pages,
        ..Default::default()
    };
    Ok(response)
}

pub async fn post_short_msg(
    request: ShortMessagePostRequest,
) -> ServiceResult<ShortMessagePostResponse> {
    let to = request.get_to().join(" ");

    let _package = fetch_package(
        "nuke.php",
        vec![
            ("__lib", "message"),
            ("__act", "message"),
            ("act", request.get_action().get_operation().to_value()),
            ("subject", request.get_subject()),
            ("content", request.get_content()),
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

    #[tokio::test]
    async fn test_get_short_msg_list() -> ServiceResult<()> {
        let response = get_short_msg_list(ShortMessageListRequest {
            page: 1,
            ..Default::default()
        })
        .await?;

        println!("response: {:?}", response);

        Ok(())
    }

    #[tokio::test]
    async fn test_get_short_msg_details() -> ServiceResult<()> {
        let response = get_short_msg_details(ShortMessageDetailsRequest {
            id: "3473951".to_owned(),
            page: 1,
            ..Default::default()
        })
        .await?;

        println!("response: {:?}", response);

        Ok(())
    }

    #[ignore]
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
            to: vec!["yricky".to_owned()].into(),
            ..Default::default()
        })
        .await?;

        println!("response: {:?}", response);

        Ok(())
    }

    #[ignore]
    #[tokio::test]
    async fn test_reply_short_msg() -> ServiceResult<()> {
        let action = ShortMessagePostAction {
            operation: ShortMessagePostAction_Operation::REPLY,
            mid: "3501275".to_owned(),
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
