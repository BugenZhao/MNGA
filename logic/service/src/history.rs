use crate::error::ServiceResult;
use cache::CACHE;
use chrono::Utc;
use protos::{
    DataModel::{Topic, TopicSnapshot},
    Message,
    Service::{TopicHistoryRequest, TopicHistoryResponse},
};
use std::cmp::Reverse;

static TOPIC_SNAPSHOT_PREFIX: &str = "/snapshot/topic";
fn topic_snapshot_key(id: &str) -> String {
    format!("{}/{}", TOPIC_SNAPSHOT_PREFIX, id)
}

pub fn insert_topic_history(topic: Topic) {
    let key = topic_snapshot_key(topic.get_id());
    let snapshot = TopicSnapshot {
        topic_snapshot: Some(topic).into(),
        timestamp: Utc::now().timestamp_millis() as u64,
        ..Default::default()
    };
    let _ = CACHE.insert_msg(&key, &snapshot);
}

pub async fn get_topic_history(request: TopicHistoryRequest) -> ServiceResult<TopicHistoryResponse> {
    let snapshots = {
        let mut ss = tokio::task::block_in_place(|| {
            CACHE
                .scan_prefix(TOPIC_SNAPSHOT_PREFIX)
                .filter_map(|p| p.ok())
                .filter_map(|(_k, v)| TopicSnapshot::parse_from_bytes(&v).ok())
                .collect::<Vec<_>>()
        });

        ss.sort_by_key(|s| Reverse(s.timestamp)); // todo: use heap
        let _ = ss.split_off((request.limit as usize).min(ss.len()));
        ss
    };

    Ok(TopicHistoryResponse {
        topics: snapshots.into(),
        ..Default::default()
    })
}
