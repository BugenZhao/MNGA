use crate::{
    error::LogicResult,
    protos::Service::{
        SubforumFilterRequest, SubforumFilterRequest_Operation, SubforumFilterResponse,
    },
};

use super::fetch_package;



pub async fn set_subforum_filter(
    request: SubforumFilterRequest,
) -> LogicResult<SubforumFilterResponse> {
    let op = match request.get_operation() {
        SubforumFilterRequest_Operation::SHOW => "del",
        SubforumFilterRequest_Operation::BLOCK => "add",
    };
    let _package = fetch_package(
        "nuke.php",
        vec![
            ("__lib", "user_option"),
            ("__act", "set"),
            (op, &request.subforum_filter_id),
        ],
        vec![
            ("fid", &request.forum_id),
            ("type", "1"),
            ("info", "add_to_block_tids"),
        ],
    )
    .await?;

    Ok(SubforumFilterResponse {
        ..Default::default()
    })
}

#[cfg(test)]
mod test {
    use super::*;

    #[tokio::test]
    async fn test_set_filter() -> LogicResult<()> {
        let response = set_subforum_filter(SubforumFilterRequest {
            forum_id: "12700430".to_owned(),
            operation: SubforumFilterRequest_Operation::BLOCK,
            ..Default::default()
        })
        .await?;

        println!("response: {:?}", response);

        Ok(())
    }
}
