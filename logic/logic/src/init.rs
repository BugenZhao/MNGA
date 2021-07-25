use std::sync::Once;

static INIT: Once = Once::new();

pub fn may_init() {
    INIT.call_once(|| {
        #[cfg(not(target_os = "android"))]
        env_logger::builder()
            .filter_level(log::LevelFilter::Info)
            .init();

        #[cfg(target_os = "android")]
        android_logger::init_once(
            android_logger::Config::default().with_min_level(log::Level::Debug),
        );
    })
}
