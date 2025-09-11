use lazy_static::lazy_static;
use protos::DataModel::{Device, RequestOption};
use std::sync::RwLock;

use crate::constants::DEFAULT_BASE_URL;

fn default_request_option() -> RequestOption {
    RequestOption {
        base_url_v2: DEFAULT_BASE_URL.to_owned(),
        device: Device::APPLE,
        random_ua: false,
        custom_ua: "".to_owned(),
        ..Default::default()
    }
}

lazy_static! {
    pub static ref REQUEST_OPTION: RwLock<RequestOption> = RwLock::new(default_request_option());
}

pub fn set_request_option(mut option: RequestOption) {
    if option.get_base_url_v2().is_empty() {
        option.set_base_url_v2(DEFAULT_BASE_URL.to_owned());
    }
    *REQUEST_OPTION.write().unwrap() = option;
}
