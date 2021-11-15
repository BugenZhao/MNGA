use crate::{
    auth, error::ServiceResult, noti::mark_noti_read, topic::extract_topic_subject,
    user::UserController,
};
use log::info;
use protos::{DataModel::PostContent, Service::*};

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
    Ok(AuthResponse {
        ..Default::default()
    })
}

pub fn handle_content_parse(request: ContentParseRequest) -> ServiceResult<ContentParseResponse> {
    let result = text::parse_content(request.get_raw()).map_or_else(
        |e| ContentParseResponse_oneof_result::error(e.to_string()),
        |spans| {
            ContentParseResponse_oneof_result::content(PostContent {
                spans: spans.into(),
                ..Default::default()
            })
        },
    );
    Ok(ContentParseResponse {
        result: Some(result).into(),
        ..Default::default()
    })
}

pub fn handle_subject_parse(request: SubjectParseRequest) -> ServiceResult<SubjectParseResponse> {
    let subject = extract_topic_subject(request.raw);
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
