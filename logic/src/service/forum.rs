use super::fetch_package;
use crate::{
    error::LogicResult,
    protos::{
        DataModel::Forum,
        Service::{
            ForumListRequest, ForumListResponse, SubforumFilterRequest,
            SubforumFilterRequest_Operation, SubforumFilterResponse,
        },
    },
    service::{
        constants::FORUM_ICON_PATH,
        utils::{extract_kv, extract_nodes},
    },
};
use sxd_xpath::nodeset::Node;

fn extract_forum(node: Node) -> Option<Forum> {
    use super::macros::get;
    let map = extract_kv(node);

    let id = get!(map, "fid")?;
    let icon_url = format!("{}/{}.png", FORUM_ICON_PATH, id);

    let forum = Forum {
        id,
        name: get!(map, "name")?,
        info: get!(map, "info").unwrap_or_default(),
        icon_url,
        ..Default::default()
    };

    Some(forum)
}

pub async fn get_forum_list(_request: ForumListRequest) -> LogicResult<ForumListResponse> {
    let package = fetch_package(
        "app_api.php",
        vec![("__lib", "home"), ("__act", "category")],
        vec![],
    )
    .await?;

    let forums = extract_nodes(&package, "/root/data/item/groups/item/forums/item", |ns| {
        ns.into_iter().filter_map(extract_forum).collect()
    })?;

    Ok(ForumListResponse {
        forums: forums.into(),
        ..Default::default()
    })
}

pub async fn set_subforum_filter(
    request: SubforumFilterRequest,
) -> LogicResult<SubforumFilterResponse> {
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

#[cfg(test)]
mod test {
    use super::*;

    #[tokio::test]
    async fn test_set_filter() -> LogicResult<()> {
        let response = set_subforum_filter(SubforumFilterRequest {
            forum_id: "12700430".to_owned(),
            operation: SubforumFilterRequest_Operation::BLOCK,
            ..Default::default()
        })
        .await?;

        println!("response: {:?}", response);

        Ok(())
    }

    #[tokio::test]
    async fn test_get_forum_list() -> LogicResult<()> {
        let response = get_forum_list(ForumListRequest::new()).await?;

        println!("response: {:?}", response);

        Ok(())
    }
}
