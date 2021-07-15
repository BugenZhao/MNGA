use crate::{
    error::LogicResult,
    service::{
        forum::{get_forum_list, search_forum, set_subforum_filter},
        history::get_topic_history,
        post::post_vote,
        topic::{get_favorite_topic_list, get_hot_topic_list, get_topic_details, get_topic_list},
        user::get_remote_user,
    },
};
use protos::Service::*;

// macro_rules! or_default {
//     ($e:expr) => {
//         $e.unwrap_or_else(|e| {
//             log::error!("{}", e);
//             Default::default()
//         })
//     };
// }

pub async fn handle_topic_list(request: TopicListRequest) -> LogicResult<TopicListResponse> {
    get_topic_list(request).await
}

pub async fn handle_topic_details(
    request: TopicDetailsRequest,
) -> LogicResult<TopicDetailsResponse> {
    get_topic_details(request).await
}

pub async fn handle_subforum_filter(
    request: SubforumFilterRequest,
) -> LogicResult<SubforumFilterResponse> {
    set_subforum_filter(request).await
}

pub async fn handle_forum_list(request: ForumListRequest) -> LogicResult<ForumListResponse> {
    get_forum_list(request).await
}

pub async fn handle_remote_user(request: RemoteUserRequest) -> LogicResult<RemoteUserResponse> {
    get_remote_user(request).await
}

pub async fn handle_post_vote(request: PostVoteRequest) -> LogicResult<PostVoteResponse> {
    post_vote(request).await
}

pub async fn handle_topic_history(
    request: TopicHistoryRequest,
) -> LogicResult<TopicHistoryResponse> {
    get_topic_history(request).await
}

pub async fn handle_hot_topic_list(
    request: HotTopicListRequest,
) -> LogicResult<HotTopicListResponse> {
    get_hot_topic_list(request).await
}

pub async fn handle_forum_search(request: ForumSearchRequest) -> LogicResult<ForumSearchResponse> {
    search_forum(request).await
}

pub async fn handle_favorite_topic_list(
    request: FavoriteTopicListRequest,
) -> LogicResult<FavoriteTopicListResponse> {
    get_favorite_topic_list(request).await
}
