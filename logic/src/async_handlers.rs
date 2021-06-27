use crate::protos::DataModel::*;
use protobuf::Message;

pub async fn handle_sleep(req: SleepRequest) -> Box<dyn Message> {
    tokio::time::sleep(tokio::time::Duration::from_millis(req.millis)).await;
    let res = SleepResponse {
        text: format!("awake after {} milliseconds", req.millis),
        ..Default::default()
    };
    Box::new(res)
}
