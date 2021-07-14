use crate::{
    protos::Service::*,
    service::{
        forum::{get_forum_list, search_forum, set_subforum_filter},
        history::get_topic_history,
        post::post_vote,
        topic::{get_favorite_topic_list, get_hot_topic_list, get_topic_details, get_topic_list},
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

pub async fn handle_post_vote(request: PostVoteRequest) -> PostVoteResponse {
    let res = post_vote(request).await;
    or_default!(res)
}

pub async fn handle_topic_history(request: TopicHistoryRequest) -> TopicHistoryResponse {
    let res = get_topic_history(request).await;
    or_default!(res)
}

pub async fn handle_hot_topic_list(request: HotTopicListRequest) -> HotTopicListResponse {
    let res = get_hot_topic_list(request).await;
    or_default!(res)
}

pub async fn handle_forum_search(request: ForumSearchRequest) -> ForumSearchResponse {
    let res = search_forum(request).await;
    or_default!(res)
}

pub async fn handle_favorite_topic_list(
    request: FavoriteTopicListRequest,
) -> FavoriteTopicListResponse {
    let res = get_favorite_topic_list(request).await;
    or_default!(res)
}
