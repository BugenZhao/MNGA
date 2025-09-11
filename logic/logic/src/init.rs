pub(crate) fn init() {
    #[cfg(not(target_os = "android"))]
    env_logger::builder()
        .filter_level(if cfg!(debug_assertions) {
            log::LevelFilter::Trace
        } else {
            log::LevelFilter::Info
        })
        .filter_module("sled", log::LevelFilter::Info) // too verbose
        .init();

    if cfg!(debug_assertions) {
        unsafe { std::env::set_var("RUST_BACKTRACE", "1") };
    }

    #[cfg(target_os = "android")]
    android_logger::init_once(android_logger::Config::default().with_min_level(log::Level::Debug));

    log::info!("initialized logic");
}
