use crate::{config, protos::Service::*, service::user::UserController};

pub fn handle_configure(mut request: ConfigureRequest) -> ConfigureResponse {
    config::set_config(request.take_config());
    ConfigureResponse::new()
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
