use crate::{
    error::ServiceResult,
    forum::{get_forum_list, search_forum, set_subforum_filter},
    history::get_topic_history,
    msg::{get_short_msg_details, get_short_msg_list, post_short_msg},
    noti::fetch_notis,
    post::{
        get_user_post_list, post_reply, post_reply_fetch_content, post_vote, upload_attachment,
    },
    topic::{
        get_favorite_topic_list, get_hot_topic_list, get_topic_details, get_topic_list,
        get_user_topic_list, topic_favor,
    },
    user::get_remote_user,
};
use protos::Service::*;

pub async fn handle_topic_list(request: TopicListRequest) -> ServiceResult<TopicListResponse> {
    get_topic_list(request).await
}

pub async fn handle_topic_details(
    request: TopicDetailsRequest,
) -> ServiceResult<TopicDetailsResponse> {
    get_topic_details(request).await
}

pub async fn handle_subforum_filter(
    request: SubforumFilterRequest,
) -> ServiceResult<SubforumFilterResponse> {
    set_subforum_filter(request).await
}

pub async fn handle_forum_list(request: ForumListRequest) -> ServiceResult<ForumListResponse> {
    get_forum_list(request).await
}

pub async fn handle_remote_user(request: RemoteUserRequest) -> ServiceResult<RemoteUserResponse> {
    get_remote_user(request).await
}

pub async fn handle_post_vote(request: PostVoteRequest) -> ServiceResult<PostVoteResponse> {
    post_vote(request).await
}

pub async fn handle_topic_history(
    request: TopicHistoryRequest,
) -> ServiceResult<TopicHistoryResponse> {
    get_topic_history(request).await
}

pub async fn handle_hot_topic_list(
    request: HotTopicListRequest,
) -> ServiceResult<HotTopicListResponse> {
    get_hot_topic_list(request).await
}

pub async fn handle_forum_search(
    request: ForumSearchRequest,
) -> ServiceResult<ForumSearchResponse> {
    search_forum(request).await
}

pub async fn handle_favorite_topic_list(
    request: FavoriteTopicListRequest,
) -> ServiceResult<FavoriteTopicListResponse> {
    get_favorite_topic_list(request).await
}

pub async fn handle_topic_favor(request: TopicFavorRequest) -> ServiceResult<TopicFavorResponse> {
    topic_favor(request).await
}

pub async fn handle_post_reply_fetch_content(
    request: PostReplyFetchContentRequest,
) -> ServiceResult<PostReplyFetchContentResponse> {
    post_reply_fetch_content(request).await
}

pub async fn handle_post_reply(request: PostReplyRequest) -> ServiceResult<PostReplyResponse> {
    post_reply(request).await
}

pub async fn handle_fetch_notification(
    request: FetchNotificationRequest,
) -> ServiceResult<FetchNotificationResponse> {
    fetch_notis(request).await
}

pub async fn handle_upload_attachment(
    request: UploadAttachmentRequest,
) -> ServiceResult<UploadAttachmentResponse> {
    upload_attachment(request).await
}

pub async fn handle_user_topic_list(
    request: UserTopicListRequest,
) -> ServiceResult<UserTopicListResponse> {
    get_user_topic_list(request).await
}

pub async fn handle_user_post_list(
    request: UserPostListRequest,
) -> ServiceResult<UserPostListResponse> {
    get_user_post_list(request).await
}

pub async fn handle_short_message_list(
    request: ShortMessageListRequest,
) -> ServiceResult<ShortMessageListResponse> {
    get_short_msg_list(request).await
}

pub async fn handle_short_message_details(
    request: ShortMessageDetailsRequest,
) -> ServiceResult<ShortMessageDetailsResponse> {
    get_short_msg_details(request).await
}

pub async fn handle_short_message_post(
    request: ShortMessagePostRequest,
) -> ServiceResult<ShortMessagePostResponse> {
    post_short_msg(request).await
}
