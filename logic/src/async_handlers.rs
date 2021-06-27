use crate::{protos::Service::*, service::topic::get_topic_list};
use protobuf::Message;

pub async fn handle_sleep(req: SleepRequest) -> Box<dyn Message> {
    tokio::time::sleep(tokio::time::Duration::from_millis(req.millis)).await;
    let res = SleepResponse {
        text: format!("awake after {} milliseconds", req.millis),
        ..Default::default()
    };
    Box::new(res)
}

pub async fn handle_topic_list(request: TopicListRequest) -> Box<dyn Message> {
    let response = get_topic_list(request).await.unwrap_or_default();
    Box::new(response)
}
