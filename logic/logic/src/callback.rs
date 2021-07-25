use service::error::ServiceResult;

use crate::byte_buffer::ByteBuffer;
use std::{ffi::c_void, mem};

pub trait CallbackTrait: Send {
    fn id(&self) -> String;
    fn run(self, result: ServiceResult<Vec<u8>>);
}

#[repr(C)]
#[derive(Debug)]
pub struct Callback {
    pub user_data: *const c_void,
    pub callback: extern "C" fn(*const c_void, ByteBuffer),
}
unsafe impl Send for Callback {}

impl Callback {
    /// # Safety
    /// total unsafe
    pub unsafe fn new(user_data: *const c_void, callback: *const c_void) -> Self {
        Self {
            user_data,
            callback: mem::transmute(callback),
        }
    }
}

impl CallbackTrait for Callback {
    fn run(self, result: ServiceResult<Vec<u8>>) {
        let byte_buffer = ByteBuffer::from(result);
        (self.callback)(self.user_data, byte_buffer)
    }

    fn id(&self) -> String {
        format!("{:?}", self.user_data)
    }
}

impl Drop for Callback {
    fn drop(&mut self) {
        log::trace!("{:?} at {:?} dropped!", self, &self as *const _)
    }
}
