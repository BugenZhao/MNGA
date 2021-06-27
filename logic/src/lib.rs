mod config;
mod error;
mod protos;
mod service;

mod async_dispatch;
mod async_handlers;
mod sync_dispatch;
mod sync_handlers;

use crate::{
    async_dispatch::{dispatch_request_async, RustCallback},
    sync_dispatch::dispatch_request,
};
use protobuf::Message;
use protos::Service::*;
use std::{ffi, mem, os::raw::c_char, ptr, slice};

unsafe fn parse_from_raw<T: Message>(data: *const u8, len: usize) -> T {
    let bytes = slice::from_raw_parts(data, len);
    T::parse_from_bytes(bytes).expect("invalid request")
}

#[repr(C)]
#[derive(Debug)]
pub struct ByteBuffer {
    pub ptr: *const u8,
    pub len: usize,
    pub cap: usize,
    pub err: *const c_char,
}

impl From<Vec<u8>> for ByteBuffer {
    fn from(v: Vec<u8>) -> Self {
        let ret = Self {
            ptr: v.as_ptr(),
            len: v.len(),
            cap: v.capacity(),
            err: ptr::null(),
        };
        println!("rust: new buffer {:?}", ret);
        mem::forget(v);
        ret
    }
}

impl ByteBuffer {
    fn from_err<E: ToString>(e: E) -> Self {
        let err_string = ffi::CString::new(e.to_string()).unwrap();
        Self {
            ptr: ptr::null(),
            len: 0,
            cap: 0,
            err: err_string.into_raw(),
        }
    }
}

impl<E: ToString> From<Result<Vec<u8>, E>> for ByteBuffer {
    fn from(result: Result<Vec<u8>, E>) -> Self {
        match result {
            Ok(v) => Self::from(v),
            Err(e) => Self::from_err(e),
        }
    }
}

/// # Safety
/// totally unsafe
#[no_mangle]
pub unsafe extern "C" fn rust_call(data: *const u8, len: usize) -> ByteBuffer {
    let request = parse_from_raw::<SyncRequest>(data, len);
    println!("rust: request {:?}", request);
    let response_buf = dispatch_request(request);
    ByteBuffer::from(response_buf)
}

/// # Safety
/// totally unsafe
#[no_mangle]
pub unsafe extern "C" fn rust_call_async(data: *const u8, len: usize, callback: RustCallback) {
    println!("rust: get {:?} at {:?}", callback, &callback as *const _);
    let request = parse_from_raw::<AsyncRequest>(data, len);
    println!("rust: async request {:?}", request);
    dispatch_request_async(request, callback);
}

/// # Safety
/// totally unsafe
#[no_mangle]
pub unsafe extern "C" fn rust_free(byte_buffer: ByteBuffer) {
    println!("rust: free buffer {:?}", byte_buffer);
    let ByteBuffer { ptr, len, cap, err } = byte_buffer;

    let buf = Vec::from_raw_parts(ptr as *mut u8, len, cap);
    drop(buf);
    if !err.is_null() {
        let err_string = ffi::CString::from_raw(err as *mut _);
        drop(err_string)
    }
}
