use crate::{async_handlers::*, error::any_err_to_string, protos::DataModel::*, ByteBuffer};
use futures::prelude::*;
use lazy_static::lazy_static;
use std::{ffi::c_void, mem, panic, thread};
use tokio::runtime::Runtime;

lazy_static! {
    static ref RUNTIME: Runtime = {
        println!("rust: creating tokio runtime");
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
        println!("rust: {:?} at {:?} dropped!", self, &self as *const _)
    }
}

macro_rules! catch_await {
    ($e: expr) => {
        panic::AssertUnwindSafe($e).catch_unwind().await
    };
}

pub fn dispatch_request_async(req: AsyncRequest, callback: RustCallback) {
    RUNTIME.spawn(async move {
        println!("rust: serving async request on {:?}", thread::current());

        use AsyncRequest_oneof_value::*;
        let response = match req.value.expect("no async req") {
            sleep(r) => catch_await!(handle_sleep(r)),
        };

        let result = response
            .map(|response| {
                let mut response_buf = Vec::with_capacity(response.compute_size() as usize + 1);
                response.write_to_vec(&mut response_buf).unwrap();
                response_buf
            })
            .map_err(any_err_to_string);

        let byte_buffer = ByteBuffer::from(result);
        callback.run(byte_buffer);
    });
}
