use crate::{
    error::LogicResult,
    service::{self, user::UserController},
};
use protos::Service::*;

pub fn handle_configure(mut request: ConfigureRequest) -> LogicResult<ConfigureResponse> {
    config::set_config(request.take_config());
    Ok(ConfigureResponse::new())
}

pub fn handle_local_user(request: LocalUserRequest) -> LogicResult<LocalUserResponse> {
    let user = UserController::get()
        .get(&request.user_id)
        .map(|e| e.value().clone());

    Ok(LocalUserResponse {
        _user: user.map(LocalUserResponse_oneof__user::user),
        ..Default::default()
    })
}

pub fn handle_auth(request: AuthRequest) -> LogicResult<AuthResponse> {
    service::auth::set_auth(request.info.unwrap());
    Ok(AuthResponse::new())
}
