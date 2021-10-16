use protos::{
    DataModel::ShortMessage,
    Service::{ShortMessageListRequest, ShortMessageListResponse},
};
use sxd_xpath::nodeset::Node;

use crate::{
    error::ServiceResult,
    fetch::fetch_package,
    utils::{extract_kv, extract_nodes},
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

    let pages = u32::MAX;

    Ok(ShortMessageListResponse {
        messages: messages.into(),
        pages,
        ..Default::default()
    })
}

#[cfg(test)]
mod test {
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
}
