use crate::protos::DataModel::Configuration;
use lazy_static::lazy_static;
use std::path::PathBuf;

static mut DOCUMENT_DIR_PATH: Option<PathBuf> = None;

lazy_static! {}

pub fn set_config(config: Configuration) {
    unsafe {
        DOCUMENT_DIR_PATH = Some(PathBuf::from(config.document_dir_path));
    }

    let cache_path = {
        let mut path = unsafe { DOCUMENT_DIR_PATH.clone().unwrap() };
        path.push("cache");
        path
    };
}
