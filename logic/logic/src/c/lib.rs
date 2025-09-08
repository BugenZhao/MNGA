use super::{byte_buffer::ByteBuffer, callback::Callback};
use crate::{
    r#async::serve_request_async, callback_trait::CallbackTrait, sync::serve_request_sync,
};
use protos::{
    Message,
    Service::{AsyncRequest, SyncRequest},
};
use std::{ffi, slice};

unsafe fn parse_from_raw<T: Message>(data: *const u8, len: usize) -> T {
    let bytes = unsafe { slice::from_raw_parts(data, len) };
    T::parse_from_bytes(bytes).expect("invalid request")
}

/// # Safety
/// totally unsafe
#[unsafe(no_mangle)]
pub unsafe extern "C" fn rust_call(data: *const u8, len: usize) -> ByteBuffer {
    let request = unsafe { parse_from_raw::<SyncRequest>(data, len) };
    log::info!("request {:?}", request);
    let response_buf = serve_request_sync(request);
    ByteBuffer::from(response_buf)
}

/// # Safety
/// totally unsafe
#[unsafe(no_mangle)]
pub unsafe extern "C" fn rust_call_async(data: *const u8, len: usize, callback: Callback) {
    log::trace!("get {:?} at {:?}", callback, &callback as *const _);
    let request = unsafe { parse_from_raw::<AsyncRequest>(data, len) };
    log::info!("async request #{} {:?}", callback.id(), request);
    serve_request_async(request, callback);
}

/// # Safety
/// totally unsafe
#[unsafe(no_mangle)]
pub unsafe extern "C" fn rust_free(byte_buffer: ByteBuffer) {
    log::trace!("free buffer {:?}", byte_buffer);
    let ByteBuffer { ptr, len, cap, err } = byte_buffer;

    let buf = unsafe { Vec::from_raw_parts(ptr as *mut u8, len, cap) };
    drop(buf);
    if !err.is_null() {
        let err_string = unsafe { ffi::CString::from_raw(err as *mut _) };
        drop(err_string)
    }
}
