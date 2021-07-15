use crate::error::{any_err_to_string, LogicError, LogicResult};
use crate::sync_handlers::*;
use protos::{Message, Service::*};
use std::{panic, thread};

macro_rules! r {
    ($r: expr) => {{
        $r.map(|m| -> Box<dyn Message> { Box::new(m) })
    }};
}

fn do_dispath(request: SyncRequest_oneof_value) -> LogicResult<Box<dyn Message>> {
    use SyncRequest_oneof_value::*;

    match request {
        configure(r) => r!(handle_configure(r)),
        local_user(r) => r!(handle_local_user(r)),
        auth(r) => r!(handle_auth(r)),
    }
}

pub fn dispatch_request(request: SyncRequest) -> LogicResult<Vec<u8>> {
    let id = format!("{:p}", &request as *const _);

    log::debug!("serving sync request #{} on {:?}", id, thread::current());

    let request = request.value.expect("no sync req");
    let response = panic::catch_unwind(|| do_dispath(request))
        .unwrap_or_else(|e| Err(LogicError::Panic(any_err_to_string(e))));

    response
        .map(|response| {
            let mut response_buf = Vec::with_capacity(response.compute_size() as usize + 1);
            response.write_to_vec(&mut response_buf).unwrap();
            response_buf
        })
        .map_err(|e| {
            log::error!("error when serving sync request #{}: {}", id, e);
            e
        })
}
