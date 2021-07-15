use crate::error::{LogicError, LogicResult};
use protos::{Service::*, Message};
use crate::{async_handlers::*, error::any_err_to_string, ByteBuffer};
use futures::prelude::*;
use lazy_static::lazy_static;
use std::{ffi::c_void, mem, panic, thread};
use tokio::runtime::Runtime;

lazy_static! {
    static ref RUNTIME: Runtime = {
        log::debug!("creating tokio runtime");
        Runtime::new().expect("failed to create tokio runtime")
    };
}

#[repr(C)]
#[derive(Debug)]
pub struct RustCallback {
    pub user_data: *const c_void,
    pub callback: extern "C" fn(*const c_void, ByteBuffer),
}
unsafe impl Send for RustCallback {}

impl RustCallback {
    /// # Safety
    /// total unsafe
    pub unsafe fn new(user_data: *const c_void, callback: *const c_void) -> Self {
        Self {
            user_data,
            callback: mem::transmute(callback),
        }
    }

    pub fn run(self, byte_buffer: ByteBuffer) {
        (self.callback)(self.user_data, byte_buffer)
    }
}

impl Drop for RustCallback {
    fn drop(&mut self) {
        log::trace!("{:?} at {:?} dropped!", self, &self as *const _)
    }
}

macro_rules! r {
    ($r: expr) => {
        panic::AssertUnwindSafe($r.map(|r| r.map(|m| -> Box<dyn Message> { Box::new(m) })))
            .catch_unwind()
            .await
    };
}

pub fn dispatch_request_async(req: AsyncRequest, callback: RustCallback) {
    let _guard = RUNTIME.enter();

    tokio::spawn(async move {
        log::debug!("serving async request on {:?}", thread::current());

        use AsyncRequest_oneof_value::*;
        let response = {
            let response: Result<LogicResult<Box<dyn Message>>, _> =
                match req.value.expect("no async req") {
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
                };
            response.unwrap_or_else(|e| Err(LogicError::Panic(any_err_to_string(e))))
        };

        let result = response
            .map(|response| {
                let mut response_buf = Vec::with_capacity(response.compute_size() as usize + 1);
                response.write_to_vec(&mut response_buf).unwrap();
                response_buf
            })
            .map_err(|e| {
                log::error!(
                    "error when serving async request #{:?}: {}",
                    callback.user_data,
                    e
                );
                e
            });

        let byte_buffer = ByteBuffer::from(result);
        callback.run(byte_buffer);
    });
}
