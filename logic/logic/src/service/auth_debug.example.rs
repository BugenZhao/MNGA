use crate::protos::DataModel::AuthInfo;
use lazy_static::lazy_static;
use std::sync::Mutex;

lazy_static! {
    pub static ref AUTH_INFO: Mutex<AuthInfo> = Mutex::new(AuthInfo {
        uid: "".to_owned(),
        token: "".to_owned(),
        ..Default::default()
    });
}

pub fn set_auth(info: AuthInfo) {
    *AUTH_INFO.lock().unwrap() = info;
}
