use std::iter::once;

use crate::{
    constants::{FORUM_ICON_PATH, MNGA_ICON_PATH},
    error::ServiceResult,
    fetch_package,
    utils::{extract_kv, extract_nodes, extract_nodes_rel},
};
use protos::{
    DataModel::{Category, Forum, ForumId, ForumId_oneof_id},
    Service::{
        ForumListRequest, ForumListResponse, ForumSearchRequest, ForumSearchResponse,
        SubforumFilterRequest, SubforumFilterRequest_Operation, SubforumFilterResponse,
    },
};
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
    let icon_url = format!("{}/{}.png", FORUM_ICON_PATH, icon_id);

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

fn extract_category(node: Node) -> Option<Category> {
    use super::macros::get;
    let map = extract_kv(node);

    let forums = extract_nodes_rel(node, "./groups/item/forums/item", |ns| {
        ns.into_iter().filter_map(extract_forum).collect()
    })
    .ok()?;

    let category = Category {
        id: get!(map, "_id")?,
        name: get!(map, "name")?,
        forums: forums.into(),
        ..Default::default()
    };

    Some(category)
}

pub async fn get_forum_list(_request: ForumListRequest) -> ServiceResult<ForumListResponse> {
    let package = fetch_package(
        "app_api.php",
        vec![("__lib", "home"), ("__act", "category")],
        vec![],
    )
    .await?;

    let categories = extract_nodes(&package, "/root/data/item", |ns| {
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
            .chain(ns.into_iter().filter_map(extract_category))
            .collect()
    })?;

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
    let _package = fetch_package(
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
}
