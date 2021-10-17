use std::{cmp::Reverse, collections::HashMap};

use protos::{
    DataModel::{Notification, Notification_Type, PostId, User},
    Service::{FetchNotificationRequest, FetchNotificationResponse},
};
use serde_json::Value;

use crate::{error::ServiceResult, fetch::fetch_json_value};

static NOTI_PREFIX: &str = "/noti_v2";
fn noti_key(noti: &Notification) -> String {
    format!("{}/{}", NOTI_PREFIX, noti.timestamp)
}

fn extract_noti(value: &Value) -> Option<Notification> {
    use super::macros::get;
    let kvs = value
        .as_object()
        .cloned()
        .unwrap_or_default()
        .into_iter()
        .map(|(k, v)| {
            (
                k,
                v.as_str().map_or_else(|| v.to_string(), |s| s.to_owned()),
            )
        })
        .collect::<HashMap<_, _>>();

    let noti_type = get!(kvs, "0", i32).map(|t| match t {
        1 => Notification_Type::REPLY_TOPIC,
        2 => Notification_Type::REPLY_POST,
        _ => Notification_Type::UNKNOWN,
    })?;

    let other_user = User {
        id: get!(kvs, "1")?,
        name: get!(kvs, "2")?,
        ..Default::default()
    };

    let topic_id = get!(kvs, "6").unwrap_or_default();
    let post_id = PostId {
        tid: topic_id.clone(),
        pid: get!(kvs, "8").unwrap_or_else(|| "0".to_owned()),
        ..Default::default()
    };
    let other_post_id = PostId {
        tid: topic_id.clone(),
        pid: get!(kvs, "7").unwrap_or_else(|| "0".to_owned()),
        ..Default::default()
    };

    let noti = Notification {
        field_type: noti_type,
        other_user: Some(other_user).into(),
        post_id: Some(post_id).into(),
        other_post_id: Some(other_post_id).into(),
        topic_subject: get!(kvs, "5")?,
        timestamp: get!(kvs, "9", _)?,
        page: get!(kvs, "10", _).unwrap_or(1),
        read: false,
        ..Default::default()
    };

    Some(noti)
}

pub async fn fetch_notis(
    _request: FetchNotificationRequest,
) -> ServiceResult<FetchNotificationResponse> {
    let value = fetch_json_value(
        "nuke.php",
        vec![("__lib", "noti"), ("__act", "get_all")],
        vec![],
    )
    .await?;

    let unread_count = value
        .pointer("0/unread")
        .and_then(|v| v.as_u64())
        .unwrap_or_default();

    let notis = value
        .pointer("/0/0")
        .and_then(|v| v.as_array())
        .map(|vs| {
            vs.iter()
                .filter_map(|v| {
                    extract_noti(v).map(|mut noti| {
                        noti.read = unread_count == 0;
                        noti
                    })
                })
                .collect::<Vec<_>>()
        })
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
