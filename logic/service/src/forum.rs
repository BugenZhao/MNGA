use std::iter::once;

use crate::{
    constants::{FORUM_ICON_PATH, MNGA_ICON_PATH},
    error::ServiceResult,
    fetch::{fetch_json_value, fetch_package},
    utils::{extract_kv, extract_nodes, json_object_values, json_string},
};
use protos::{
    DataModel::{Category, Forum, ForumId, ForumId_oneof_id},
    Service::{
        FavoriteForumListRequest, FavoriteForumListResponse, FavoriteForumModifyRequest,
        FavoriteForumModifyRequest_Operation, FavoriteForumModifyResponse, ForumListRequest,
        ForumListResponse, ForumSearchRequest, ForumSearchResponse, SubforumFilterRequest,
        SubforumFilterRequest_Operation, SubforumFilterResponse,
    },
};
use serde_json::Value;
use sxd_xpath::nodeset::Node;

#[inline]
pub fn make_fid(id: String) -> Option<ForumId> {
    if !id.is_empty() && id != "0" {
        ForumId {
            id: Some(ForumId_oneof_id::fid(id)),
            ..Default::default()
        }
        .into()
    } else {
        None
    }
}

#[inline]
pub fn make_stid(id: String) -> Option<ForumId> {
    if !id.is_empty() && id != "0" {
        ForumId {
            id: Some(ForumId_oneof_id::stid(id)),
            ..Default::default()
        }
        .into()
    } else {
        None
    }
}

pub fn extract_forum(node: Node) -> Option<Forum> {
    use super::macros::get;
    let map = extract_kv(node);

    let icon_id = get!(map, "id")
        .or_else(|| get!(map, "fid"))
        .unwrap_or_default();
    let icon_url = format!("{}{}.png", FORUM_ICON_PATH, icon_id);

    let fid = get!(map, "fid").map(make_fid).flatten();
    let stid = get!(map, "stid").map(make_stid).flatten();

    let forum = Forum {
        id: stid.or(fid).into(), // stid first
        name: get!(map, "name")?,
        info: get!(map, "info").unwrap_or_default(),
        icon_url,
        topped_topic_id: get!(map, "topped_topic").unwrap_or_default(),
        ..Default::default()
    };

    Some(forum)
}

pub fn make_minimal_forum(id: ForumId, name: String) -> Forum {
    let icon_id = if id.has_fid() {
        id.get_fid()
    } else if id.has_stid() {
        id.get_stid()
    } else {
        "0"
    };
    let icon_url = format!("{}{}.png", FORUM_ICON_PATH, icon_id);

    Forum {
        id: Some(id).into(),
        name,
        icon_url,
        ..Default::default()
    }
}

fn extract_forum_json(value: &Value) -> Option<Forum> {
    let icon_id = json_string(value, "id")
        .or_else(|| json_string(value, "fid"))
        .unwrap_or_default();
    let fid = json_string(value, "fid").and_then(make_fid);
    let stid = json_string(value, "stid").and_then(make_stid);

    Some(Forum {
        id: stid.or(fid).into(),
        name: json_string(value, "name")?,
        info: json_string(value, "info").unwrap_or_default(),
        icon_url: format!("{}{}.png", FORUM_ICON_PATH, icon_id),
        topped_topic_id: json_string(value, "topped_topic").unwrap_or_default(),
        ..Default::default()
    })
}

fn extract_category_json(value: &Value) -> Option<Category> {
    let forums: Vec<_> = value
        .get("groups")?
        .as_object()?
        .values()
        .flat_map(|group| {
            group
                .get("forums")
                .and_then(Value::as_object)
                .into_iter()
                .flat_map(|forums| forums.values())
        })
        .filter_map(extract_forum_json)
        .collect();

    Some(Category {
        id: json_string(value, "_id")?,
        name: json_string(value, "name")?,
        forums: forums.into(),
        ..Default::default()
    })
}

pub async fn get_forum_list(_request: ForumListRequest) -> ServiceResult<ForumListResponse> {
    let value = fetch_json_value(
        "app_api.php",
        vec![("__lib", "home"), ("__act", "category")],
        vec![],
    )
    .await?;

    let categories: Vec<_> = {
        // todo: dynamic
        let mnga_category = Category {
            id: "mnga".to_owned(),
            name: "MNGA".to_owned(),
            forums: vec![Forum {
                id: make_fid("mnga_root_0".to_owned()).into(),
                name: "MNGA Meta".to_owned(),
                icon_url: MNGA_ICON_PATH.to_owned(),
                ..Default::default()
            }]
            .into(),
            ..Default::default()
        };

        once(mnga_category)
            .chain(json_object_values(&value).filter_map(extract_category_json))
            .collect()
    };

    Ok(ForumListResponse {
        categories: categories.into(),
        ..Default::default()
    })
}

pub async fn set_subforum_filter(
    request: SubforumFilterRequest,
) -> ServiceResult<SubforumFilterResponse> {
    let op = match request.get_operation() {
        SubforumFilterRequest_Operation::SHOW => "del",
        SubforumFilterRequest_Operation::BLOCK => "add",
    };
    let _value = fetch_json_value(
        "nuke.php",
        vec![
            ("__lib", "user_option"),
            ("__act", "set"),
            (op, &request.subforum_filter_id),
        ],
        vec![
            ("fid", &request.forum_id),
            ("type", "1"),
            ("info", "add_to_block_tids"),
        ],
    )
    .await?;

    Ok(SubforumFilterResponse {
        ..Default::default()
    })
}

pub async fn search_forum(request: ForumSearchRequest) -> ServiceResult<ForumSearchResponse> {
    let package = fetch_package("forum.php", vec![("key", request.get_key())], vec![]).await?;

    let forums = extract_nodes(&package, "/root/item", |ns| {
        ns.into_iter().filter_map(extract_forum).collect()
    })?;

    Ok(ForumSearchResponse {
        forums: forums.into(),
        ..Default::default()
    })
}

pub async fn get_favorite_forum_list(
    _request: FavoriteForumListRequest,
) -> ServiceResult<FavoriteForumListResponse> {
    let value = fetch_json_value(
        "nuke.php",
        vec![("__lib", "forum_favor2"), ("__act", "forum_favor")],
        vec![("action", "get")],
    )
    .await?;

    let forums: Vec<_> = value
        .get("0")
        .and_then(Value::as_object)
        .into_iter()
        .flat_map(|forums| forums.values())
        .filter_map(extract_forum_json)
        .collect();

    Ok(FavoriteForumListResponse {
        forums: forums.into(),
        ..Default::default()
    })
}

pub async fn modify_favorite_forum(
    request: FavoriteForumModifyRequest,
) -> ServiceResult<FavoriteForumModifyResponse> {
    use crate::error::ServiceError;

    let action = match request.get_operation() {
        FavoriteForumModifyRequest_Operation::ADD => "add",
        FavoriteForumModifyRequest_Operation::DEL => "del",
    };

    let id = if request.get_id().has_fid() {
        request.get_id().get_fid().to_owned()
    } else if request.get_id().has_stid() {
        request.get_id().get_stid().to_owned()
    } else {
        return Err(ServiceError::MissingField(
            "FavoriteForumModifyRequest.id".to_owned(),
        ));
    };

    let _value = fetch_json_value(
        "nuke.php",
        vec![("__lib", "forum_favor2"), ("__act", "forum_favor")],
        vec![("action", action), ("fid", &id)],
    )
    .await?;

    Ok(FavoriteForumModifyResponse {
        ..Default::default()
    })
}

#[cfg(test)]
mod test {
    use crate::fetch::with_fetch_check;

    use super::*;

    #[tokio::test]
    async fn test_set_filter() -> ServiceResult<()> {
        let _response = with_fetch_check(
            |r| assert!(r.contains("操作成功")),
            set_subforum_filter(SubforumFilterRequest {
                forum_id: "310".to_owned(),
                subforum_filter_id: "19115466".to_owned(),
                operation: SubforumFilterRequest_Operation::SHOW,
                ..Default::default()
            }),
        )
        .await?;

        Ok(())
    }

    #[tokio::test]
    async fn test_get_forum_list() -> ServiceResult<()> {
        let response = get_forum_list(ForumListRequest::new()).await?;

        println!("response: {:?}", response);

        let forum_exists = response
            .get_categories()
            .iter()
            .flat_map(|c| c.get_forums())
            .any(|f| f.name == "晴风村");
        assert!(forum_exists);

        Ok(())
    }

    #[tokio::test]
    async fn test_search_forum_chinese() -> ServiceResult<()> {
        let response = search_forum(ForumSearchRequest {
            key: "原神".to_owned(),
            ..Default::default()
        })
        .await?;

        println!("response: {:?}", response);

        let forum_exists = response.get_forums().iter().any(|f| f.name == "原神");
        assert!(forum_exists);

        Ok(())
    }

    #[tokio::test]
    async fn test_search_forum_not_exist() -> ServiceResult<()> {
        let response = search_forum(ForumSearchRequest {
            key: "元神".to_owned(),
            ..Default::default()
        })
        .await?;

        println!("response: {:?}", response);

        assert!(response.get_forums().is_empty());

        Ok(())
    }

    #[tokio::test]
    async fn test_get_favorite_forum_list() -> ServiceResult<()> {
        let response = get_favorite_forum_list(FavoriteForumListRequest::new()).await?;

        println!("response: {:?}", response);

        Ok(())
    }

    #[ignore = "manual: requires network or mutable external state"]
    #[tokio::test]
    async fn test_favorite_forum() -> ServiceResult<()> {
        let response = get_favorite_forum_list(FavoriteForumListRequest::new()).await?;
        let favor1 = response.get_forums();

        for id in [make_fid("708".to_owned()), make_stid("16667422".to_owned())] {
            let _response = modify_favorite_forum(FavoriteForumModifyRequest {
                id: id.clone().into(),
                operation: FavoriteForumModifyRequest_Operation::ADD,
                ..Default::default()
            })
            .await?;

            let response = get_favorite_forum_list(FavoriteForumListRequest::new()).await?;
            let favor2 = response.get_forums();

            assert_eq!(favor1.len() + 1, favor2.len());
            assert!(favor2.iter().any(|f| f.id == id.clone().into()));

            let _response = modify_favorite_forum(FavoriteForumModifyRequest {
                id: id.into(),
                operation: FavoriteForumModifyRequest_Operation::DEL,
                ..Default::default()
            })
            .await?;

            let response = get_favorite_forum_list(FavoriteForumListRequest::new()).await?;
            let favor3 = response.get_forums();

            assert_eq!(favor1, favor3);
        }

        Ok(())
    }
}
