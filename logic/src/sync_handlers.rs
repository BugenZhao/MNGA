use crate::protos::DataModel::*;
use protobuf::Message;

pub fn handle_greeting(req: GreetingRequest) -> Box<dyn Message> {
    let res = GreetingResponse {
        text: format!("{}, {}!", req.get_verb(), req.get_name()),
        ..Default::default()
    };
    Box::new(res)
}
