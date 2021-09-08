use crate::{auth, error::ServiceResult, topic::extract_topic_subject, user::UserController};
use protos::{DataModel::PostContent, Service::*};

pub fn handle_configure(mut request: ConfigureRequest) -> ServiceResult<ConfigureResponse> {
    config::set_config(request.take_config());
    Ok(ConfigureResponse::new())
}

pub fn handle_local_user(request: LocalUserRequest) -> ServiceResult<LocalUserResponse> {
    let user = UserController::get()
        .get(&request.user_id)
        .map(|e| e.value().clone());

    Ok(LocalUserResponse {
        _user: user.map(LocalUserResponse_oneof__user::user),
        ..Default::default()
    })
}

pub fn handle_auth(request: AuthRequest) -> ServiceResult<AuthResponse> {
    auth::set_auth(request.info.unwrap());
    Ok(AuthResponse::new())
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
