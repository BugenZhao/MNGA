#[ctor::ctor]
fn init() {
    #[cfg(not(target_os = "android"))]
    env_logger::builder()
        .filter_level(log::LevelFilter::Info)
        .init();

    #[cfg(target_os = "android")]
    android_logger::init_once(android_logger::Config::default().with_min_level(log::Level::Debug));

    log::info!("initialized logic");
}
