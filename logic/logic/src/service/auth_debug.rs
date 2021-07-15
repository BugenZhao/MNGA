use lazy_static::lazy_static;
use protos::DataModel::AuthInfo;
use std::sync::Mutex;

lazy_static! {
    pub static ref AUTH_INFO: Mutex<AuthInfo> = {
        dotenv::dotenv().ok();
        Mutex::new(AuthInfo {
            uid: dotenv::var("AUTH_DEBUG_UID").unwrap_or("".to_owned()),
            token: dotenv::var("AUTH_DEBUG_TOKEN").unwrap_or("".to_owned()),
            ..Default::default()
        })
    };
}

pub fn set_auth(info: AuthInfo) {
    *AUTH_INFO.lock().unwrap() = info;
}
