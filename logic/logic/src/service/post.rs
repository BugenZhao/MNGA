use super::fetch_package;
use crate::{
    error::LogicResult,
    service::utils::{extract_kv, extract_node_rel, extract_nodes_rel, extract_string},
};
use cache::CACHE;
use protos::{DataModel::*, Service::*};
use sxd_xpath::nodeset::Node;

fn vote_response_key(id: &PostId) -> String {
    format!("/vote_response/topic/{}/post/{}", id.tid, id.pid)
}

pub fn extract_post(node: Node) -> Option<Post> {
    use super::macros::get;
    let map = extract_kv(node);

    let raw_content = get!(map, "content")?;
    let spans = text::parse_content(&raw_content).unwrap_or_else(|_| {
        vec![Span {
            value: Some(Span_oneof_value::plain(Span_Plain {
                text: raw_content.clone(),
                ..Default::default()
            })),
            ..Default::default()
        }]
    });
    let content = PostContent {
        spans: spans.into(),
        raw: raw_content,
        ..Default::default()
    };

    let post_id = PostId {
        pid: get!(map, "pid")?,
        tid: get!(map, "tid")?,
        ..Default::default()
    };

    let vote_state = CACHE
        .get_msg::<PostVoteResponse>(&vote_response_key(&post_id))
        .ok()
        .flatten()
        .map(|r| r.state)
        .unwrap_or(VoteState::NONE);

    let hot_replies = extract_nodes_rel(node, "./hotreply/item", |ns| {
        ns.into_iter().filter_map(extract_post).collect()
    })
    .unwrap_or_default();

    let device = {
        let device = extract_node_rel(node, ".//from_client", |n| n.string_value())
            .ok()
            .flatten()
            .unwrap_or_default()
            .to_lowercase();

        if device.contains("android") {
            Post_Device::ANDROID
        } else if device.contains("ios") {
            Post_Device::APPLE
        } else {
            Post_Device::OTHER
        }
    };

    let post = Post {
        id: Some(post_id).into(),
        floor: get!(map, "lou", u32)?,
        author_id: get!(map, "authorid")?,
        content: Some(content).into(),
        post_date: get!(map, "postdatetimestamp", _)?,
        score: get!(map, "score", _)?,
        vote_state,
        host_replies: hot_replies.into(),
        device,
        ..Default::default()
    };

    Some(post)
}

pub async fn post_vote(request: PostVoteRequest) -> LogicResult<PostVoteResponse> {
    use std::cmp::Ordering::*;
    use PostVoteRequest_Operation::*;

    let value = match request.get_operation() {
        UPVOTE => "1",
        DOWNVOTE => "-1",
    };

    let package = fetch_package(
        "nuke.php",
        vec![
            ("__lib", "topic_recommend"),
            ("__act", "add"),
            ("value", value),
            ("tid", request.get_post_id().get_tid()),
            ("pid", request.get_post_id().get_pid()),
        ],
        vec![],
    )
    .await?;

    let delta = extract_string(&package, "/root/data/item[2]")?
        .parse::<i32>()
        .unwrap_or_default();

    let state = match (request.get_operation(), delta.cmp(&0)) {
        (UPVOTE, Greater) => VoteState::UP,
        (DOWNVOTE, Less) => VoteState::DOWN,
        (_, _) => VoteState::NONE,
    };

    let response = PostVoteResponse {
        delta,
        state,
        ..Default::default()
    };
    let _ = CACHE.insert_msg(&vote_response_key(request.get_post_id()), &response);

    Ok(response)
}

#[cfg(test)]
mod test {
    use super::*;
    use protos::DataModel::PostId;

    #[tokio::test]
    async fn test_post_vote() -> LogicResult<()> {
        use PostVoteRequest_Operation::*;
        let vote = |op| {
            post_vote(PostVoteRequest {
                post_id: Some(PostId {
                    tid: "27477718".to_owned(),
                    pid: "0".to_owned(),
                    ..Default::default()
                })
                .into(),
                operation: op,
                ..Default::default()
            })
        };

        while vote(UPVOTE).await.unwrap().delta != -1 {}

        assert_eq!(vote(UPVOTE).await.unwrap().delta, 1);
        assert_eq!(vote(UPVOTE).await.unwrap().delta, -1);
        assert_eq!(vote(UPVOTE).await.unwrap().delta, 1);
        assert_eq!(vote(DOWNVOTE).await.unwrap().delta, -2);
        assert_eq!(vote(DOWNVOTE).await.unwrap().delta, 1);

        Ok(())
    }
}
