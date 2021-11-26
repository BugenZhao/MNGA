use std::{
    sync::atomic::{AtomicU64, Ordering},
    time::{SystemTime, UNIX_EPOCH},
};

pub fn get_unique_id() -> String {
    static NEXT: AtomicU64 = AtomicU64::new(0);
    format!("mnga_{}", NEXT.fetch_add(1, Ordering::SeqCst))
}

pub fn now() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs()
}
