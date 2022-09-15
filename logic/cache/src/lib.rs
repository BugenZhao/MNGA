pub mod error;

use lazy_static::lazy_static;
use std::ops::Deref;

pub use error::{CacheError, CacheResult};

lazy_static! {
    pub static ref CACHE: Cache = {
        let (db, is_test) = match config::CONF.get().map(|c| &c.cache_path) {
            Some(path) => {
                log::debug!("open db at {:?}", path);
                let db = sled::Config::new()
                    .path(path)
                    .flush_every_ms(Some(3000))
                    .cache_capacity(20 * 1024 * 1024)
                    .open()
                    .expect("cannot open or create cache db");
                (db, false)
            }
            None => {
                log::warn!("no cache path conf provided, use temporary location and treat it as a test environment");
                let db = sled::Config::new()
                    .temporary(true)
                    .open()
                    .expect("cannot open or create temporary cache db");
                (db, true)
            }
        };

        Cache::new(db, is_test)
    };
}

pub struct Cache {
    db: sled::Db,
    is_test: bool,
}

impl Deref for Cache {
    type Target = sled::Db;

    fn deref(&self) -> &Self::Target {
        &self.db
    }
}

impl Cache {
    fn new(db: sled::Db, is_test: bool) -> Self {
        Self { db, is_test }
    }

    fn do_insert_msg<M: protos::Message>(&self, key: &str, msg: &M) -> CacheResult<Option<M>> {
        log::info!("insert: key={}", key);
        let key_bytes = key.as_bytes();
        let value = msg.write_to_bytes()?;
        let last = self.db.insert(key_bytes, value)?;
        let last_msg = last.and_then(|ivec| M::parse_from_bytes(&ivec).ok());
        Ok(last_msg)
    }

    fn do_get_msg<M: protos::Message>(&self, key: &str) -> CacheResult<Option<M>> {
        let key_bytes = key.as_bytes();
        let value = self.db.get(key_bytes)?;
        let value_msg = value.and_then(|ivec| M::parse_from_bytes(&ivec).ok());
        log::debug!(
            "get: key={}, msg={}",
            key,
            if value_msg.is_some() { "Some" } else { "None" }
        );
        Ok(value_msg)
    }

    fn do_mutate_msg<M: protos::Message>(
        &self,
        key: &str,
        mutate: impl FnOnce(&mut M),
    ) -> CacheResult<Option<M>> {
        let key_bytes = key.as_bytes();
        let value = self.db.get(key_bytes)?;
        let mut value_msg = value.and_then(|ivec| M::parse_from_bytes(&ivec).ok());

        if let Some(msg) = value_msg.as_mut() {
            mutate(msg);
            let value = msg.write_to_bytes()?;
            self.db.insert(key_bytes, value)?;
            log::debug!("mutate: key={}", key);
        }

        Ok(value_msg)
    }

    fn do_scan_msg<M: protos::Message>(&self, prefix: &str) -> impl Iterator<Item = M> {
        self.db
            .scan_prefix(prefix)
            .filter_map(|r| r.ok().and_then(|(_k, v)| M::parse_from_bytes(&v).ok()))
    }

    fn do_remove_prefix(&self, prefix: &str) -> CacheResult<usize> {
        let mut batch = sled::Batch::default();
        let mut count = 0;
        for r in self.db.scan_prefix(prefix) {
            let (k, _v) = r?;
            batch.remove(k);
            count += 1;
        }
        self.db.apply_batch(batch)?;
        self.db.flush()?;
        Ok(count)
    }

    #[allow(unused_results)]
    pub fn insert_msg<M: protos::Message>(&self, key: &str, msg: &M) -> CacheResult<Option<M>> {
        if self.is_test {
            // using single threaded runtime
            self.do_insert_msg(key, msg)
        } else {
            tokio::task::block_in_place(move || self.do_insert_msg(key, msg))
        }
    }

    pub fn get_msg<M: protos::Message>(&self, key: &str) -> CacheResult<Option<M>> {
        if self.is_test {
            // using single threaded runtime
            self.do_get_msg(key)
        } else {
            tokio::task::block_in_place(move || self.do_get_msg(key))
        }
    }

    pub fn mutate_msg<M: protos::Message>(
        &self,
        key: &str,
        mutate: impl FnOnce(&mut M),
    ) -> CacheResult<Option<M>> {
        if self.is_test {
            self.do_mutate_msg(key, mutate)
        } else {
            tokio::task::block_in_place(move || self.do_mutate_msg(key, mutate))
        }
    }

    pub fn scan_msg<M: protos::Message>(&self, prefix: &str) -> impl Iterator<Item = M> {
        if self.is_test {
            // using single threaded runtime
            self.do_scan_msg(prefix)
        } else {
            tokio::task::block_in_place(move || self.do_scan_msg(prefix))
        }
    }

    pub fn remove_prefix(&self, prefix: &str) -> CacheResult<usize> {
        if self.is_test {
            // using single threaded runtime
            self.do_remove_prefix(prefix)
        } else {
            tokio::task::block_in_place(move || self.do_remove_prefix(prefix))
        }
    }

    pub fn total_size(&self) -> CacheResult<u64> {
        self.db.size_on_disk().map_err(Into::into)
    }
}
