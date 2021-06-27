use crate::{protos::Service::*, service::user::UserController};

pub fn handle_greeting(request: GreetingRequest) -> GreetingResponse {
    GreetingResponse {
        text: format!("{}, {}!", request.get_verb(), request.get_name()),
        ..Default::default()
    }
}

pub fn handle_local_user(request: LocalUserRequest) -> LocalUserResponse {
    let user = UserController::get()
        .get(&request.user_id)
        .map(|e| e.value().clone());

    let mut response = LocalUserResponse::new();
    if let Some(user) = user {
        response.set_user(user)
    }
    response
}
