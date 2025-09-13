use cache::CACHE;
use protos::{
    DataModel::{CacheOperation, CacheType},
    Service::{CacheRequest, CacheResponse},
};

use crate::{
    error::ServiceResult, history::TOPIC_SNAPSHOT_PREFIX, noti::NOTI_PREFIX,
    topic::TOPIC_DETAILS_PREFIX,
};

fn type_to_prefix(t: CacheType) -> &'static str {
    match t {
        CacheType::ALL => "/",
        CacheType::TOPIC_HISTORY => TOPIC_SNAPSHOT_PREFIX,
        CacheType::TOPIC_DETAILS => TOPIC_DETAILS_PREFIX,
        CacheType::NOTIFICATION => NOTI_PREFIX,
    }
}

pub async fn manipulate_cache(request: CacheRequest) -> ServiceResult<CacheResponse> {
    let prefix = type_to_prefix(request.get_field_type());
    let items = match request.get_operation() {
        CacheOperation::CHECK => CACHE.scan_prefix(prefix).count(),
        CacheOperation::CLEAR => {
            let _removed_count = CACHE.remove_prefix(prefix)?;
            CACHE.scan_prefix(prefix).count()
        }
    };
    let total_size = CACHE.total_size()?;

    Ok(CacheResponse {
        items: items as u64,
        total_size,
        ..Default::default()
    })
}

#[cfg(test)]
mod test {
    use crate::utils::get_unique_id;

    use super::*;

    use protos::DataModel::{CacheType::*, Subject};

    #[tokio::test]
    async fn test_clear_cache() -> ServiceResult<()> {
        let insert = |tp: CacheType, count: u64| {
            let example_msg = || Subject {
                tags: vec!["Tag".to_owned()].into(),
                content: "Content".to_owned(),
                ..Default::default()
            };
            let prefix = type_to_prefix(tp);
            for _ in 0..count {
                CACHE
                    .insert_msg(&format!("{}/{}", prefix, get_unique_id()), &example_msg())
                    .unwrap();
            }
            CACHE.flush().unwrap();
        };

        let clear = |tp: CacheType| async move {
            let request = CacheRequest {
                field_type: tp,
                operation: CacheOperation::CLEAR,
                ..Default::default()
            };
            manipulate_cache(request).await
        };

        let check = |tp: CacheType| async move {
            let request = CacheRequest {
                field_type: tp,
                operation: CacheOperation::CHECK,
                ..Default::default()
            };
            manipulate_cache(request).await
        };

        const N: u64 = 100;

        insert(NOTIFICATION, N * 3);
        insert(NOTIFICATION, N);
        insert(TOPIC_HISTORY, N);
        insert(TOPIC_DETAILS, N * 5);

        assert_eq!(check(ALL).await?.get_items(), N * 10);

        assert_eq!(check(NOTIFICATION).await?.get_items(), N * 4);
        assert_eq!(clear(NOTIFICATION).await?.get_items(), N * 4);
        assert_eq!(check(NOTIFICATION).await?.get_items(), 0);
        assert_eq!(clear(NOTIFICATION).await?.get_items(), 0);

        assert_eq!(check(ALL).await?.get_items(), N * 6);
        assert_eq!(clear(ALL).await?.get_items(), N * 6);
        assert_eq!(check(ALL).await?.get_items(), 0);

        Ok(())
    }
}
