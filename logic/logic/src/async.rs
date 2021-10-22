use crate::callback_trait::CallbackTrait;
use lazy_static::lazy_static;
use protos::Service::*;
use service::dispatch_async;
use std::thread;
use tokio::runtime::Runtime;

lazy_static! {
    static ref RUNTIME: Runtime = {
        log::debug!("creating tokio runtime");
        Runtime::new().expect("failed to create tokio runtime")
    };
}

pub fn serve_request_async<Cb>(request: AsyncRequest, callback: Cb)
where
    Cb: CallbackTrait,
{
    let _guard = RUNTIME.enter();

    tokio::spawn(async move {
        let _ = &request;
        log::debug!("serving async request on {:?}", thread::current());

        let request = request.value.expect("no async req");
        let response = dispatch_async(request).await;

        let result = response
            .map(|response| {
                let mut response_buf = Vec::with_capacity(response.compute_size() as usize + 1);
                response.write_to_vec(&mut response_buf).unwrap();
                response_buf
            })
            .map_err(|e| {
                log::error!(
                    "error when serving async request #{:?}: {}",
                    callback.id(),
                    e
                );
                e
            });

        callback.run(result);
    });
}
