mod handlers_async;
mod handlers_sync;

mod dispatch_async {
    use super::handlers_async::*;
    use crate::error::{any_err_to_string, ServiceError, ServiceResult};
    use futures::prelude::*;
    use protos::{Message, Service::AsyncRequest_oneof_value};
    use std::panic::AssertUnwindSafe;

    macro_rules! r {
        ($r: expr) => {
            AssertUnwindSafe($r.map(|r| r.map(|m| -> Box<dyn Message> { Box::new(m) })))
                .catch_unwind()
                .unwrap_or_else(|e| Err(ServiceError::Panic(any_err_to_string(e))))
                .await
        };
    }

    pub async fn dispatch_async(
        request: AsyncRequest_oneof_value,
    ) -> ServiceResult<Box<dyn Message>> {
        use protos::Service::AsyncRequest_oneof_value::*;
        match request {
            topic_list(r) => r!(handle_topic_list(r)),
            topic_details(r) => r!(handle_topic_details(r)),
            subforum_filter(r) => r!(handle_subforum_filter(r)),
            forum_list(r) => r!(handle_forum_list(r)),
            remote_user(r) => r!(handle_remote_user(r)),
            post_vote(r) => r!(handle_post_vote(r)),
            topic_history(r) => r!(handle_topic_history(r)),
            hot_topic_list(r) => r!(handle_hot_topic_list(r)),
            forum_search(r) => r!(handle_forum_search(r)),
            favorite_topic_list(r) => r!(handle_favorite_topic_list(r)),
            topic_favor(r) => r!(handle_topic_favor(r)),
            post_reply_fetch_content(r) => r!(handle_post_reply_fetch_content(r)),
            post_reply(r) => r!(handle_post_reply(r)),
            fetch_notification(r) => r!(handle_fetch_notification(r)),
            upload_attachment(r) => r!(handle_upload_attachment(r)),
            user_topic_list(r) => r!(handle_user_topic_list(r)),
            user_post_list(r) => r!(handle_user_post_list(r)),
            short_message_list(r) => r!(handle_short_message_list(r)),
            short_message_details(r) => r!(handle_short_message_details(r)),
            short_message_post(r) => r!(handle_short_message_post(r)),
            topic_search(r) => r!(handle_topic_search(r)),
            clock_in(r) => r!(handle_clock_in(r)),
            cache(r) => r!(handle_cache(r)),
        }
    }
}

mod dispatch_sync {
    use super::handlers_sync::*;
    use crate::error::{any_err_to_string, ServiceError, ServiceResult};
    use protos::{Message, Service::*};
    use std::panic::catch_unwind;

    macro_rules! r {
        ($r: expr) => {{
            catch_unwind(|| $r.map(|m| -> Box<dyn Message> { Box::new(m) }))
                .unwrap_or_else(|e| Err(ServiceError::Panic(any_err_to_string(e))))
        }};
    }

    pub fn dispatch_sync(request: SyncRequest_oneof_value) -> ServiceResult<Box<dyn Message>> {
        use SyncRequest_oneof_value::*;

        match request {
            configure(r) => r!(handle_configure(r)),
            local_user(r) => r!(handle_local_user(r)),
            auth(r) => r!(handle_auth(r)),
            content_parse(r) => r!(handle_content_parse(r)),
            subject_parse(r) => r!(handle_subject_parse(r)),
            mark_noti_read(r) => r!(handle_mark_noti_read(r)),
            set_request_option(r) => r!(handle_set_request_option(r)),
        }
    }
}

pub use dispatch_async::dispatch_async;
pub use dispatch_sync::dispatch_sync;
