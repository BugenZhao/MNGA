use std::sync::Once;

static INIT: Once = Once::new();

pub fn may_init() {
    INIT.call_once(|| {
        env_logger::builder()
            .filter_level(log::LevelFilter::Info)
            .init();
    })
}
