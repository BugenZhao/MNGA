use crate::{
    protos::Service::*,
    service::{
        forum::{get_forum_list, set_subforum_filter},
        topic::{get_topic_details, get_topic_list},
        user::get_remote_user,
    },
};

macro_rules! or_default {
    ($e:expr) => {
        $e.unwrap_or_else(|e| {
            log::error!("{:?}", e);
            Default::default()
        })
    };
}

pub async fn handle_topic_list(request: TopicListRequest) -> TopicListResponse {
    let res = get_topic_list(request).await;
    or_default!(res)
}

pub async fn handle_topic_details(request: TopicDetailsRequest) -> TopicDetailsResponse {
    let res = get_topic_details(request).await;
    or_default!(res)
}

pub async fn handle_subforum_filter(request: SubforumFilterRequest) -> SubforumFilterResponse {
    let res = set_subforum_filter(request).await;
    or_default!(res)
}

pub async fn handle_forum_list(request: ForumListRequest) -> ForumListResponse {
    let res = get_forum_list(request).await;
    or_default!(res)
}

pub async fn handle_remote_user(request: RemoteUserRequest) -> RemoteUserResponse {
    let res = get_remote_user(request).await;
    or_default!(res)
}
