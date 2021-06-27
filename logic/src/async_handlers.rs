use crate::{
    protos::Service::*,
    service::topic::{get_topic_details, get_topic_list},
};

pub async fn handle_sleep(req: SleepRequest) -> SleepResponse {
    tokio::time::sleep(tokio::time::Duration::from_millis(req.millis)).await;
    SleepResponse {
        text: format!("awake after {} milliseconds", req.millis),
        ..Default::default()
    }
}

pub async fn handle_topic_list(request: TopicListRequest) -> TopicListResponse {
    get_topic_list(request).await.unwrap_or_else(|e| {
        println!("rust error: {:?}", e);
        Default::default()
    })
}

pub async fn handle_topic_details(request: TopicDetailsRequest) -> TopicDetailsResponse {
    get_topic_details(request).await.unwrap_or_else(|e| {
        println!("rust error: {:?}", e);
        Default::default()
    })
}
