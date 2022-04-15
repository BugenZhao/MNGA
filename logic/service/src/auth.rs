use lazy_static::lazy_static;
use protos::DataModel::AuthInfo;
use std::sync::RwLock;

#[cfg(test)]
fn default_auth_info() -> AuthInfo {
    dotenv::dotenv().ok();
    AuthInfo {
        uid: dotenv::var("AUTH_DEBUG_UID").expect("uid for debug is not set"),
        token: dotenv::var("AUTH_DEBUG_TOKEN").expect("token for debug is not set"),
        ..Default::default()
    }
}

#[cfg(not(test))]
fn default_auth_info() -> AuthInfo {
    AuthInfo::new()
}

lazy_static! {
    pub static ref AUTH_INFO: RwLock<AuthInfo> = RwLock::new(default_auth_info());
}

pub fn set_auth(info: AuthInfo) {
    *AUTH_INFO.write().unwrap() = info;
}

pub fn current_uid() -> String {
    AUTH_INFO.read().unwrap().get_uid().to_owned()
}
