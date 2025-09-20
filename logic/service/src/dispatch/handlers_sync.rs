use crate::{
    auth, error::ServiceResult, fetch::invalidate_global_client, noti::mark_noti_read, request,
    user::UserController,
};
use log::info;
use protos::Service::*;

pub fn handle_configure(request: ConfigureRequest) -> ServiceResult<ConfigureResponse> {
    config::set_config(request.config.unwrap());
    if request.debug {
        cache::CACHE.clear().expect("failed to clear the cache");
        info!("cleared the cache");
    }
    Ok(ConfigureResponse::new())
}

pub fn handle_local_user(request: LocalUserRequest) -> ServiceResult<LocalUserResponse> {
    let user = UserController::get().get_by_id(request.get_user_id());

    Ok(LocalUserResponse {
        user: user.into(),
        ..Default::default()
    })
}

pub fn handle_auth(request: AuthRequest) -> ServiceResult<AuthResponse> {
    auth::set_auth(request.info.unwrap());
    Ok(Default::default())
}

pub fn handle_content_parse(request: ContentParseRequest) -> ServiceResult<ContentParseResponse> {
    let content = text::parse_content(request.get_raw());
    Ok(ContentParseResponse {
        content: Some(content).into(),
        ..Default::default()
    })
}

pub fn handle_subject_parse(request: SubjectParseRequest) -> ServiceResult<SubjectParseResponse> {
    let subject = text::parse_subject(request.get_raw());
    Ok(SubjectParseResponse {
        subject: Some(subject).into(),
        ..Default::default()
    })
}

pub fn handle_mark_noti_read(
    request: MarkNotificationReadRequest,
) -> ServiceResult<MarkNotificationReadResponse> {
    mark_noti_read(request)
}

pub fn handle_set_request_option(
    request: SetRequestOptionRequest,
) -> ServiceResult<SetRequestOptionResponse> {
    request::set_request_option(request.option.unwrap());
    Ok(Default::default())
}

pub fn handle_invalidate_client(
    _: InvalidateClientRequest,
) -> ServiceResult<InvalidateClientResponse> {
    invalidate_global_client();
    Ok(Default::default())
}
