use std::collections::HashMap;

use protos::{
    DataModel::{Activity, Activity_Type, PostId, Topic, User},
    ProtobufEnum,
    Service::{ActivityListRequest, ActivityListResponse},
};
use sxd_document::Package;
use sxd_xpath::nodeset::Node;

use crate::{
    error::ServiceResult,
    fetch_package,
    topic::extract_topic,
    user::extract_local_user_and_cache,
    utils::{extract_nodes, extract_nodes_rel, extract_string, extract_string_rel},
};

fn parse_activity_list(package: &Package) -> ServiceResult<ActivityListResponse> {
    let users = extract_nodes(package, "/root/data/item[2]/item", |ns| {
        ns.into_iter()
            .filter_map(|n| extract_local_user_and_cache(n, None))
            .collect::<Vec<_>>()
    })?
    .into_iter()
    .map(|u| (u.get_id().to_owned(), u))
    .collect::<HashMap<_, _>>();

    let topics = extract_nodes(package, "/root/data/item[5]/item", |ns| {
        ns.into_iter().filter_map(extract_topic).collect::<Vec<_>>()
    })?
    .into_iter()
    .map(|t| (t.get_id().to_owned(), t))
    .collect::<HashMap<_, _>>();

    let activities = extract_nodes(package, "/root/data/item[1]/item", |ns| {
        ns.into_iter()
            .filter_map(|n| extract_activity(n, &users, &topics).ok().flatten())
            .collect::<Vec<_>>()
    })?;

    let pages = extract_string(package, "/root/data/item[3]")?
        .parse::<u32>()
        .unwrap_or(1);

    Ok(ActivityListResponse {
        activities: activities.into(),
        pages,
        ..Default::default()
    })
}

fn extract_activity(
    node: Node,
    users: &HashMap<String, User>,
    topics: &HashMap<String, Topic>,
) -> ServiceResult<Option<Activity>> {
    let values = extract_nodes_rel(node, "./item", |ns| {
        ns.into_iter().map(|n| n.string_value()).collect()
    })?;

    let id = values.first().cloned().unwrap_or_default();
    if id.is_empty() {
        return Ok(None);
    }

    let type_raw = values.get(1).cloned().unwrap_or_default();
    let field_type = type_raw
        .parse::<i32>()
        .ok()
        .and_then(Activity_Type::from_i32)
        .unwrap_or(Activity_Type::UNKNOWN);

    let actor_id = values.get(2).cloned().unwrap_or_default();
    let topic_id = values.get(3).cloned().unwrap_or_default();
    let pid = values.get(4).cloned().unwrap_or_else(|| "0".to_owned());
    let timestamp = values
        .get(6)
        .and_then(|s| s.parse::<u64>().ok())
        .unwrap_or_default();

    let summary = extract_string_rel(node, "./summary").unwrap_or_default();
    let summary = text::unescape(&summary);

    let actor = users.get(&actor_id).cloned().unwrap_or(User {
        id: actor_id,
        ..Default::default()
    });

    let topic = topics.get(&topic_id).cloned().unwrap_or(Topic {
        id: topic_id.clone(),
        ..Default::default()
    });

    let post_id = PostId {
        tid: topic_id,
        pid,
        ..Default::default()
    };

    Ok(Some(Activity {
        id,
        field_type,
        actor: Some(actor).into(),
        topic: Some(topic).into(),
        post_id: Some(post_id).into(),
        timestamp,
        summary,
        ..Default::default()
    }))
}

pub async fn get_activity_list(
    request: ActivityListRequest,
) -> ServiceResult<ActivityListResponse> {
    let package = fetch_package(
        "nuke.php",
        vec![
            ("__lib", "follow_v2"),
            ("__act", "get_push_list"),
            ("page", &request.get_page().to_string()),
        ],
        vec![],
    )
    .await?;

    parse_activity_list(&package)
}

#[cfg(test)]
mod test {
    use super::*;

    #[test]
    fn test_parse_activity_list_minimal() -> ServiceResult<()> {
        let xml = r#"
<root>
  <data>
    <item>
      <item>
        <item>123</item>
        <item>1</item>
        <item>42</item>
        <item>999</item>
        <item>0</item>
        <item>0</item>
        <item>1700000000</item>
        <item>0</item>
        <summary>hello &amp; world</summary>
      </item>
    </item>
    <item>
      <item>
        <uid>42</uid>
        <username>tester</username>
      </item>
    </item>
    <item>3</item>
    <item>1</item>
    <item>
      <item>
        <tid>999</tid>
        <fid>1</fid>
        <author>tester</author>
        <authorid>42</authorid>
        <subject>test</subject>
        <postdate>1700000000</postdate>
        <lastpost>1700000000</lastpost>
        <replies>0</replies>
      </item>
    </item>
  </data>
  <time>1700000001</time>
</root>
"#;

        let package = sxd_document::parser::parse(xml)?;
        let response = parse_activity_list(&package)?;

        assert_eq!(response.get_pages(), 3);
        assert_eq!(response.get_activities().len(), 1);

        let a = &response.get_activities()[0];
        assert_eq!(a.get_id(), "123");
        assert_eq!(a.get_field_type(), Activity_Type::POST_TOPIC);
        assert_eq!(a.get_actor().get_id(), "42");
        assert_eq!(a.get_topic().get_id(), "999");
        assert_eq!(a.get_post_id().get_pid(), "0");
        assert_eq!(a.get_timestamp(), 1700000000);
        assert_eq!(a.get_summary(), "hello & world");

        Ok(())
    }

    #[tokio::test]
    async fn test_activity_list() -> ServiceResult<()> {
        let response = get_activity_list(ActivityListRequest {
            page: 1,
            ..Default::default()
        })
        .await?;
        assert!(!response.get_activities().is_empty());
        Ok(())
    }
}
