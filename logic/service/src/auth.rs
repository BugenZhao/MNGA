use lazy_static::lazy_static;
use protos::DataModel::AuthInfo;
use std::sync::Mutex;

#[cfg(test)]
fn default_auth_info() -> AuthInfo {
    use crate::constants;

    dotenv::dotenv().ok();
    AuthInfo {
        uid: dotenv::var("AUTH_DEBUG_UID").unwrap_or("".to_owned()),
        token: dotenv::var("AUTH_DEBUG_TOKEN").unwrap_or("".to_owned()),
        ..Default::default()
    }
}

#[cfg(not(test))]
fn default_auth_info() -> AuthInfo {
    AuthInfo::new()
}

lazy_static! {
    pub static ref AUTH_INFO: Mutex<AuthInfo> = Mutex::new(default_auth_info());
}

pub fn set_auth(info: AuthInfo) {
    *AUTH_INFO.lock().unwrap() = info;
}
