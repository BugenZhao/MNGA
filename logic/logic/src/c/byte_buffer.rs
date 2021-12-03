use std::{ffi, mem, os::raw::c_char, ptr};

use service::error::ServiceResult;

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
        // todo: use into_raw_parts when stable
        let ret = Self {
            ptr: v.as_ptr(),
            len: v.len(),
            cap: v.capacity(),
            err: ptr::null(),
        };
        log::trace!("new buffer {:?}", ret);
        mem::forget(v);
        ret
    }
}

impl ByteBuffer {
    fn from_err_string(string: String) -> Self {
        let err_string = ffi::CString::new(string).unwrap();
        Self {
            ptr: ptr::null(),
            len: 0,
            cap: 0,
            err: err_string.into_raw(),
        }
    }
}

impl From<ServiceResult<Vec<u8>>> for ByteBuffer {
    fn from(result: ServiceResult<Vec<u8>>) -> Self {
        match result {
            Ok(v) => Self::from(v),
            Err(e) => Self::from_err_string(e.to_app_string()),
        }
    }
}
