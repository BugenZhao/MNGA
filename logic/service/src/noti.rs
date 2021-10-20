use std::{cmp::Reverse, collections::HashMap};

use protos::{
    DataModel::{Notification, Notification_Type, PostId, User},
    ProtobufEnum,
    Service::{
        FetchNotificationRequest, FetchNotificationResponse, MarkNotificationReadRequest,
        MarkNotificationReadResponse,
    },
};
use serde_json::Value;

use crate::{error::ServiceResult, fetch::fetch_json_value, topic::extract_topic_subject};

static NOTI_PREFIX: &str = "/noti_v2";
fn noti_key(id: &str) -> String {
    format!("{}/{}", NOTI_PREFIX, id)
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

    let noti_type = get!(kvs, "0", i32)
        .and_then(Notification_Type::from_i32)
        .unwrap_or(Notification_Type::UNKNOWN);

    let other_user = User {
        id: get!(kvs, "1").unwrap_or_default(),
        name: get!(kvs, "2").unwrap_or_default(),
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

    let timestamp = get!(kvs, "9", _)?;
    let id = format!(
        "{}-{}-{}-{}",
        timestamp,
        noti_type as i32,
        other_post_id.get_tid(),
        other_post_id.get_pid()
    );

    let topic_subject = extract_topic_subject(get!(kvs, "5").unwrap_or_default());

    let noti = Notification {
        id,
        field_type: noti_type,
        other_user: Some(other_user).into(),
        post_id: Some(post_id).into(),
        other_post_id: Some(other_post_id).into(),
        topic_subject: Some(topic_subject).into(),
        timestamp,
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

    // let unread_count = value
    //     .pointer("0/unread")
    //     .and_then(|v| v.as_u64())
    //     .unwrap_or_default();

    let notis = {
        let mut notis = vec![];
        for pointer in ["/0/0", "/0/1", "/0/2"] {
            let iter = value
                .pointer(pointer)
                .and_then(|v| v.as_array())
                .map(|vs| vs.iter().filter_map(|v| extract_noti(v)));
            if let Some(iter) = iter {
                notis.extend(iter);
            }
        }
        notis
    };

    notis.into_iter().for_each(|noti| {
        let key = noti_key(noti.get_id());
        let not_exist = cache::CACHE
            .get_msg::<Notification>(&key)
            .ok()
            .flatten()
            .is_none();
        if not_exist {
            let _ = cache::CACHE.insert_msg(&key, &noti);
        }
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

pub fn mark_noti_read(
    request: MarkNotificationReadRequest,
) -> ServiceResult<MarkNotificationReadResponse> {
    request
        .ids
        .iter()
        .map(|id| noti_key(id.as_str()))
        .for_each(|key| {
            let _ = cache::CACHE.mutate_msg(&key, |noti: &mut Notification| {
                noti.set_read(true);
            });
        });

    Ok(Default::default())
}

#[cfg(test)]
mod test {
    use super::*;

    #[tokio::test]
    async fn test_notis() -> ServiceResult<()> {
        let response = fetch_notis(FetchNotificationRequest::new()).await?;
        println!("response: {:?}", response);

        let all_unread = response.get_notis().iter().all(|noti| !noti.read);
        assert!(all_unread);

        if let Some(noti) = response.get_notis().first() {
            let id = noti.get_id();
            mark_noti_read(MarkNotificationReadRequest {
                ids: vec![id.to_owned()].into(),
                ..Default::default()
            })?;

            let new_response = fetch_notis(FetchNotificationRequest::new()).await?;
            let marked = new_response
                .get_notis()
                .iter()
                .find(|noti| noti.id == id)
                .unwrap()
                .read
                == true;
            assert!(marked);
        }

        Ok(())
    }
}
