use crate::{
    cache::manipulate_cache,
    clock_in::clock_in,
    error::ServiceResult,
    forum::{get_forum_list, search_forum, set_subforum_filter},
    history::get_topic_history,
    msg::{get_short_msg_details, get_short_msg_list, post_short_msg},
    noti::fetch_notis,
    post::{
        get_user_post_list, post_reply, post_reply_fetch_content, post_vote, upload_attachment,
    },
    topic::{
        create_favorite_folder, get_favorite_folder_list, get_favorite_topic_list,
        get_hot_topic_list, get_topic_details, get_topic_list, get_user_topic_list,
        modify_favorite_folder, search_topic, topic_favor,
    },
    user::get_remote_user,
};
use paste::paste;
use protos::Service::*;

macro_rules! handle {
    ($service: ident, $fn: ident) => {
        paste! {
            pub async fn [<handle_ $service:snake>](request: [<$service:camel Request>]) -> ServiceResult<[<$service:camel Response>]> {
                $fn(request).await
            }
        }
    };
}

handle!(topic_list, get_topic_list);
handle!(topic_details, get_topic_details);
handle!(subforum_filter, set_subforum_filter);
handle!(forum_list, get_forum_list);
handle!(remote_user, get_remote_user);
handle!(post_vote, post_vote);
handle!(topic_history, get_topic_history);
handle!(hot_topic_list, get_hot_topic_list);
handle!(forum_search, search_forum);
handle!(favorite_topic_list, get_favorite_topic_list);
handle!(favorite_folder_list, get_favorite_folder_list);
handle!(favorite_folder_create, create_favorite_folder);
handle!(favorite_folder_modify, modify_favorite_folder);
handle!(topic_favor, topic_favor);
handle!(post_reply_fetch_content, post_reply_fetch_content);
handle!(post_reply, post_reply);
handle!(fetch_notification, fetch_notis);
handle!(upload_attachment, upload_attachment);
handle!(user_topic_list, get_user_topic_list);
handle!(user_post_list, get_user_post_list);
handle!(short_message_list, get_short_msg_list);
handle!(short_message_details, get_short_msg_details);
handle!(short_message_post, post_short_msg);
handle!(topic_search, search_topic);
handle!(clock_in, clock_in);
handle!(cache, manipulate_cache);
