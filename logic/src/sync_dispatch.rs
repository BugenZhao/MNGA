use crate::error::any_err_to_string;
use crate::protos::Service::*;
use crate::sync_handlers::*;
use protobuf::Message;
use std::{panic, thread};

macro_rules! r {
    ($e: expr) => {{
        let b: Box<dyn Message> = Box::new($e);
        b
    }};
}

pub fn dispatch_request(req: SyncRequest) -> Result<Vec<u8>, String> {
    println!("rust: serving sync request on {:?}", thread::current());

    use SyncRequest_oneof_value::*;
    let response = panic::catch_unwind(|| match req.value.expect("no sync req") {
        greeting(r) => r!(handle_greeting(r)),
    });

    response
        .map(|response| {
            let mut response_buf = Vec::with_capacity(response.compute_size() as usize + 1);
            response.write_to_vec(&mut response_buf).unwrap();
            response_buf
        })
        .map_err(any_err_to_string)
}
