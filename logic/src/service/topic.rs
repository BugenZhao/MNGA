use sxd_xpath::nodeset::Node;

use crate::{
    error::{LogicError, LogicResult},
    protos::{
        DataModel::{Reply, Topic, User},
        Service::*,
    },
    service::{
        fetch_package,
        user::UserController,
        utils::{extract_kv, extract_node, extract_nodeset},
    },
};

fn extract_topic(node: Node) -> Option<Topic> {
    use super::macros::get;
    let map = extract_kv(node);

    let topic = Topic {
        id: get!(map, "tid"),
        subject: get!(map, "subject"),
        author_id: get!(map, "authorid"),
        author_name: get!(map, "author"),
        post_date: get!(map, "postdate", u64),
        last_post_date: get!(map, "lastpost", u64),
        ..Default::default()
    };

    Some(topic)
}

fn extract_user(node: Node) -> Option<User> {
    use super::macros::get;
    let map = extract_kv(node);

    let user = User {
        id: get!(map, "uid"),
        name: get!(map, "username"),
        avatar_url: get!(map, "avatar"),
        reg_date: get!(map, "regdate", _),
        post_num: get!(map, "postnum", _),
        ..Default::default()
    };

    Some(user)
}

fn extract_reply(node: Node) -> Option<Reply> {
    use super::macros::get;
    let map = extract_kv(node);

    let reply = Reply {
        floor: get!(map, "lou", u32),
        author_id: get!(map, "authorid"),
        content: get!(map, "content"),
        post_date: get!(map, "postdatetimestamp", _),
        score: get!(map, "score", _),
        ..Default::default()
    };

    Some(reply)
}

pub async fn get_topic_list(request: TopicListRequest) -> LogicResult<TopicListResponse> {
    let package = fetch_package(
        "thread.php",
        vec![
            ("fid", &request.forum_id),
            ("page", &request.page.to_string()),
        ],
    )
    .await?;

    let topics = extract_nodeset(&package, "/root/__T/item", |ns| {
        ns.into_iter().filter_map(extract_topic).collect()
    })?;

    Ok(TopicListResponse {
        topics: topics.into(),
        ..Default::default()
    })
}

pub async fn get_topic_details(request: TopicDetailsRequest) -> LogicResult<TopicDetailsResponse> {
    let package = fetch_package(
        "read.php",
        vec![
            ("tid", &request.topic_id),
            ("page", &request.page.to_string()),
        ],
    )
    .await?;

    let users = extract_nodeset(&package, "/root/__U/item", |ns| {
        ns.into_iter().filter_map(extract_user).collect()
    })?;
    UserController::get().update_users(users);

    let replies = {
        let mut replies = extract_nodeset(&package, "/root/__R/item", |ns| {
            ns.into_iter().filter_map(extract_reply).collect()
        })?;
        replies.sort_by_key(|r| r.floor);
        replies
    };

    let topic = extract_node(&package, "/root/__T", extract_topic)?.flatten();
    if topic.is_none() {
        return Err(LogicError::MissingField("topic".to_owned()));
    }

    Ok(TopicDetailsResponse {
        topic: topic.into(),
        replies: replies.into(),
        pages: 1,
        ..Default::default()
    })
}

#[cfg(test)]
mod test {
    use super::*;

    #[tokio::test]
    async fn test_topic_list() -> LogicResult<()> {
        let response = get_topic_list(TopicListRequest {
            forum_id: "-7".to_owned(),
            page: 1,
            ..Default::default()
        })
        .await?;

        println!("response: {:?}", response);

        assert!(!response.get_topics().is_empty());

        Ok(())
    }

    #[tokio::test]
    async fn test_topic_details() -> LogicResult<()> {
        let response = get_topic_details(TopicDetailsRequest {
            topic_id: "27351344".to_owned(),
            page: 1,
            ..Default::default()
        })
        .await?;

        println!("response: {:?}", response);

        assert!(!response.get_topic().get_id().is_empty());
        assert!(!response.get_replies().is_empty());
        assert!(!UserController::get().is_empty());

        Ok(())
    }
}
