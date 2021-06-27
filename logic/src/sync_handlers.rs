use crate::protos::Service::*;

pub fn handle_greeting(req: GreetingRequest) -> GreetingResponse {
    GreetingResponse {
        text: format!("{}, {}!", req.get_verb(), req.get_name()),
        ..Default::default()
    }
}
