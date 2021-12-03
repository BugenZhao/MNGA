use protos::Service::*;
use service::dispatch_sync;
use service::error::ServiceResult;
use std::thread;

pub fn serve_request_sync(request: SyncRequest) -> ServiceResult<Vec<u8>> {
    let id = format!("{:p}", &request as *const _);

    log::debug!("serving sync request #{} on {:?}", id, thread::current());

    let request = request.value.expect("no sync req");
    let response = dispatch_sync(request);

    response
        .map(|response| {
            let mut response_buf = Vec::with_capacity(response.compute_size() as usize + 1);
            response.write_to_vec(&mut response_buf).unwrap();
            response_buf
        })
        .map_err(|e| {
            log::error!(
                "error when serving sync request #{}: {}",
                id,
                e.to_app_string()
            );
            e
        })
}
