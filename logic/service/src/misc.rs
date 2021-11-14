use protos::Service::{ClockInRequest, ClockInResponse};

use crate::{error::ServiceResult, fetch::fetch_package};

pub async fn clock_in(_request: ClockInRequest) -> ServiceResult<ClockInResponse> {
    let _package = fetch_package(
        "nuke.php",
        vec![("__lib", "check_in"), ("__act", "check_in")],
        vec![],
    )
    .await?;

    Ok(ClockInResponse::default())
}

#[cfg(test)]
mod test {
    use super::*;

    #[tokio::test]
    #[ignore]
    async fn test_clock_in() -> ServiceResult<()> {
        clock_in(ClockInRequest::default()).await?;
        Ok(())
    }
}
