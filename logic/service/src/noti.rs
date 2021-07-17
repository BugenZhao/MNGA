use std::cmp::Reverse;

use protos::{
    DataModel::{Notification, Notification_Type, PostId, User},
    Service::{FetchNotificationRequest, FetchNotificationResponse},
};
use sxd_xpath::nodeset::Node;

use crate::{
    error::ServiceResult,
    fetch::fetch_package,
    utils::{extract_kv_pairs, extract_nodes, extract_string},
};

static NOTI_PREFIX: &str = "/noti";
fn noti_key(noti: &Notification) -> String {
    format!("{}/{}", NOTI_PREFIX, noti.timestamp)
}

fn extract_noti(node: Node) -> Option<Notification> {
    use super::macros::pget;
    let pairs = extract_kv_pairs(node);

    let noti_type = pget!(pairs, 1, i32).map(|t| match t {
        1 => Notification_Type::REPLY_TOPIC,
        2 => Notification_Type::REPLY_POST,
        _ => Notification_Type::UNKNOWN,
    })?;

    let other_user = User {
        id: pget!(pairs, 2)?,
        name: pget!(pairs, pairs.len() - 3)?,
        ..Default::default()
    };

    let topic_id = pget!(pairs, pairs.len() - 7).unwrap_or_default();

    // todo
    let post_id = PostId {
        tid: topic_id.clone(),
        pid: "0".to_owned(),
        ..Default::default()
    };

    Some(Notification {
        field_type: noti_type,
        other_user: Some(other_user).into(),
        topic_subject: pget!(pairs, pairs.len() - 1)?,
        timestamp: pget!(pairs, 0, u64)?,
        page: pget!(pairs, pairs.len() - 5, u32).unwrap_or_default(),
        post_id: Some(post_id.clone()).into(), // todo
        other_post_id: Some(post_id).into(),   // todo
        ..Default::default()
    })
}

pub async fn fetch_notis(
    _request: FetchNotificationRequest,
) -> ServiceResult<FetchNotificationResponse> {
    let package = fetch_package(
        "nuke.php",
        vec![("__lib", "noti"), ("__act", "get_all")],
        vec![],
    )
    .await?;

    let unread_count = extract_string(&package, "/root/data/item[1]/unread")
        .ok()
        .and_then(|s| s.parse::<u32>().ok())
        .unwrap_or_default();

    let notis = extract_nodes(&package, "/root/data/item[1]/item/item", |ns| {
        ns.into_iter()
            .filter_map(|node| {
                extract_noti(node).map(|mut noti| {
                    noti.read = unread_count == 0;
                    noti
                })
            })
            .collect()
    })
    .ok()
    .unwrap_or_default();

    notis.into_iter().for_each(|noti| {
        let _ = cache::CACHE.insert_msg(&noti_key(&noti), &noti);
    });

    let notis = {
        let mut notis = cache::CACHE
            .scan_msg::<Notification>(NOTI_PREFIX)
            .collect::<Vec<_>>();
        notis.sort_by_key(|n| Reverse(n.timestamp));
        notis.into()
    };

    Ok(FetchNotificationResponse {
        notis,
        ..Default::default()
    })
}

#[cfg(test)]
mod test {
    use super::*;

    #[tokio::test]
    async fn test_fetch_notis() -> ServiceResult<()> {
        let response = fetch_notis(FetchNotificationRequest::new()).await?;

        println!("response: {:?}", response);

        Ok(())
    }
}
