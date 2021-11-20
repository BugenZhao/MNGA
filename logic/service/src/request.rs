use lazy_static::lazy_static;
use protos::DataModel::{Device, RequestOption};
use std::sync::RwLock;

use crate::constants::DEFAULT_BASE_URL;

fn default_request_option() -> RequestOption {
    RequestOption {
        base_url: DEFAULT_BASE_URL.to_owned(),
        device: Device::APPLE,
        ..Default::default()
    }
}

lazy_static! {
    pub static ref REQUEST_OPTION: RwLock<RequestOption> = RwLock::new(default_request_option());
}

pub fn set_request_option(mut option: RequestOption) {
    if option.get_base_url().is_empty() {
        option.set_base_url(DEFAULT_BASE_URL.to_owned());
    }
    *REQUEST_OPTION.write().unwrap() = option;
}
