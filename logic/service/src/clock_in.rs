use cache::CACHE;
use protos::Service::{ClockInRequest, ClockInResponse};

use crate::{
    auth::current_uid, error::ServiceResult, fetch::fetch_package, utils::server_today_string,
};

fn clock_in_key() -> String {
    format!("/clock_in/user/{}", current_uid())
}

fn clocked_in_today() -> ServiceResult<bool> {
    let last = CACHE.get_msg::<ClockInResponse>(&clock_in_key())?;
    Ok(last
        .map(|r| r.date == server_today_string())
        .unwrap_or_default())
}

pub async fn clock_in(_request: ClockInRequest) -> ServiceResult<ClockInResponse> {
    let mut response = ClockInResponse {
        date: server_today_string(),
        ..Default::default()
    };

    if !clocked_in_today()? {
        let _package = fetch_package(
            "nuke.php",
            vec![("__lib", "check_in"), ("__act", "check_in")],
            vec![],
        )
        .await?;
        let _ = CACHE.insert_msg(&clock_in_key(), &response)?;
        response.is_first_time = true;
    }

    Ok(response)
}

#[cfg(test)]
mod test {
    use super::*;

    #[tokio::test]
    #[ignore]
    async fn test_clock_in() -> ServiceResult<()> {
        clock_in(ClockInRequest::default()).await?;
        assert!(clocked_in_today().unwrap());
        Ok(())
    }
}
