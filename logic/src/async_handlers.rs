use crate::{
    protos::Service::*,
    service::{
        forum::set_subforum_filter,
        topic::{get_topic_details, get_topic_list},
    },
};

macro_rules! or_default {
    ($e:expr) => {
        $e.unwrap_or_else(|e| {
            println!("rust error: {:?}", e);
            Default::default()
        })
    };
}

pub async fn handle_sleep(req: SleepRequest) -> SleepResponse {
    tokio::time::sleep(tokio::time::Duration::from_millis(req.millis)).await;
    SleepResponse {
        text: format!("awake after {} milliseconds", req.millis),
        ..Default::default()
    }
}

pub async fn handle_topic_list(request: TopicListRequest) -> TopicListResponse {
    let res = get_topic_list(request).await;
    or_default!(res)
}

pub async fn handle_topic_details(request: TopicDetailsRequest) -> TopicDetailsResponse {
    let res = get_topic_details(request).await;
    or_default!(res)
}

pub async fn handle_subforum_filter(request: SubforumFilterRequest) -> SubforumFilterResponse {
    let res = set_subforum_filter(request).await;
    or_default!(res)
}
