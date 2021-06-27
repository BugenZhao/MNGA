use sxd_xpath::nodeset::Node;

use crate::{
    error::LogicResult,
    protos::{
        DataModel::Topic,
        Service::{TopicListRequest, TopicListResponse},
    },
    service::{fetch_package, utils::extract_map},
};

pub async fn get_topic_list(request: TopicListRequest) -> LogicResult<TopicListResponse> {
    let package = fetch_package(
        "thread.php",
        vec![
            ("fid", &request.forum_id),
            ("page", &request.page.to_string()),
        ],
    )
    .await?;
    let document = package.as_document();
    let v = sxd_xpath::evaluate_xpath(&document, "/root/__T/item")?;

    fn extract_topic(node: Node) -> Option<Topic> {
        let map = extract_map(node);

        let id = map.get("tid")?.to_owned();
        let subject = map.get("subject")?.to_owned();
        let author = map.get("author")?.to_owned();
        let post_date = map.get("postdate")?.parse::<u64>().ok()?;
        let last_post_date = map.get("lastpost")?.parse::<u64>().ok()?;

        let topic = Topic {
            id,
            subject,
            author,
            post_date,
            last_post_date,
            ..Default::default()
        };

        Some(topic)
    }

    let topics = if let sxd_xpath::Value::Nodeset(nodeset) = v {
        nodeset
            .into_iter()
            .filter_map(extract_topic)
            .collect::<Vec<_>>()
    } else {
        vec![]
    };

    Ok(TopicListResponse {
        topics: topics.into(),
        ..Default::default()
    })
}

#[cfg(test)]
mod test {
    use super::*;

    #[tokio::test]
    async fn test_works() {
        let response = get_topic_list(TopicListRequest {
            forum_id: "-7".to_owned(),
            page: 1,
            ..Default::default()
        })
        .await;

        println!("response: {:?}", response);
    }
}
