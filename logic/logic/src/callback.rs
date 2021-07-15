use crate::byte_buffer::ByteBuffer;
use std::{ffi::c_void, mem};

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

    pub fn run(self, byte_buffer: ByteBuffer) {
        (self.callback)(self.user_data, byte_buffer)
    }
}

impl Drop for Callback {
    fn drop(&mut self) {
        log::trace!("{:?} at {:?} dropped!", self, &self as *const _)
    }
}
