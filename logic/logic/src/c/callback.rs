use super::byte_buffer::ByteBuffer;
use crate::callback_trait::CallbackTrait;
use service::error::ServiceResult;
use std::{ffi::c_void, mem};

type CallbackFn = extern "C" fn(*const c_void, ByteBuffer);

#[repr(C)]
#[derive(Debug)]
pub struct Callback {
    pub user_data: *const c_void,
    pub callback: CallbackFn,
}
unsafe impl Send for Callback {}

impl Callback {
    /// # Safety
    /// total unsafe
    #[allow(dead_code)]
    pub unsafe fn new(user_data: *const c_void, callback: *const c_void) -> Self {
        Self {
            user_data,
            callback: unsafe { mem::transmute::<*const c_void, CallbackFn>(callback) },
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
