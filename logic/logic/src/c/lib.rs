use super::{byte_buffer::ByteBuffer, callback::Callback};
use crate::{
    callback_trait::CallbackTrait, init::may_init, r#async::serve_request_async,
    sync::serve_request_sync,
};
use protos::{
    Message,
    Service::{AsyncRequest, SyncRequest},
};
use std::{ffi, slice};

unsafe fn parse_from_raw<T: Message>(data: *const u8, len: usize) -> T {
    let bytes = slice::from_raw_parts(data, len);
    T::parse_from_bytes(bytes).expect("invalid request")
}

/// # Safety
/// totally unsafe
#[no_mangle]
pub unsafe extern "C" fn rust_call(data: *const u8, len: usize) -> ByteBuffer {
    may_init();
    let request = parse_from_raw::<SyncRequest>(data, len);
    log::info!("request {:?}", request);
    let response_buf = serve_request_sync(request);
    ByteBuffer::from(response_buf)
}

/// # Safety
/// totally unsafe
#[no_mangle]
pub unsafe extern "C" fn rust_call_async(data: *const u8, len: usize, callback: Callback) {
    may_init();
    log::trace!("get {:?} at {:?}", callback, &callback as *const _);
    let request = parse_from_raw::<AsyncRequest>(data, len);
    log::info!("async request #{} {:?}", callback.id(), request);
    serve_request_async(request, callback);
}

/// # Safety
/// totally unsafe
#[no_mangle]
pub unsafe extern "C" fn rust_free(byte_buffer: ByteBuffer) {
    may_init();
    log::trace!("free buffer {:?}", byte_buffer);
    let ByteBuffer { ptr, len, cap, err } = byte_buffer;

    let buf = Vec::from_raw_parts(ptr as *mut u8, len, cap);
    drop(buf);
    if !err.is_null() {
        let err_string = ffi::CString::from_raw(err as *mut _);
        drop(err_string)
    }
}
