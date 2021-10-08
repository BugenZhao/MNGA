use once_cell::sync::OnceCell;
use protos::DataModel;
use std::path::PathBuf;

#[derive(Debug)]
pub struct Conf {
    pub document_dir_path: PathBuf,
    pub cache_path: PathBuf,
    pub test_path: PathBuf,
}

pub static CONF: OnceCell<Conf> = OnceCell::new();

pub fn set_config(config: DataModel::Configuration) {
    let document_dir_path = PathBuf::from(config.document_dir_path);
    let cache_path = {
        let mut path = document_dir_path.clone();
        path.push("logic_cache.sled");
        path
    };
    let test_path = {
        let mut path = document_dir_path.clone();
        path.push("test.txt");
        path
    };

    let conf = Conf {
        document_dir_path,
        cache_path,
        test_path,
    };

    match CONF.set(conf) {
        Ok(_) => {}
        Err(_) => {
            log::warn!("failed to set configuration, maybe already set?")
        }
    }
}
