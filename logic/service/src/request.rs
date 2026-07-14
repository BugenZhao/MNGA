use lazy_static::lazy_static;
use protos::DataModel::{Device, RequestOption};
use std::sync::RwLock;

use crate::constants::DEFAULT_BASE_URL;

const LEGACY_BASE_URLS: &[&str] = &["https://nga.178.com", "https://nga.178.com/"];

fn normalize_base_url(base_url: &str) -> String {
    if base_url.is_empty() || LEGACY_BASE_URLS.contains(&base_url) {
        DEFAULT_BASE_URL.to_owned()
    } else {
        base_url.to_owned()
    }
}

fn default_request_option() -> RequestOption {
    RequestOption {
        base_url_v2: DEFAULT_BASE_URL.to_owned(),
        device: Device::APPLE,
        custom_ua: "".to_owned(),
        ..Default::default()
    }
}

lazy_static! {
    pub static ref REQUEST_OPTION: RwLock<RequestOption> = RwLock::new(default_request_option());
}

pub fn set_request_option(mut option: RequestOption) {
    option.set_base_url_v2(normalize_base_url(option.get_base_url_v2()));
    *REQUEST_OPTION.write().unwrap() = option;
}

#[cfg(test)]
mod test {
    use super::*;

    #[test]
    fn test_normalize_base_url() {
        assert_eq!(normalize_base_url(""), DEFAULT_BASE_URL);
        assert_eq!(normalize_base_url("https://nga.178.com"), DEFAULT_BASE_URL);
        assert_eq!(normalize_base_url("https://nga.178.com/"), DEFAULT_BASE_URL);
        assert_eq!(
            normalize_base_url("https://ngabbs.com"),
            "https://ngabbs.com"
        );
    }
}
