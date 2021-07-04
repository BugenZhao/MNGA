use super::fetch_package;
use crate::{
    cache::CACHE,
    error::LogicResult,
    protos::{DataModel::*, Service::*},
    service::{
        text,
        utils::{extract_kv, extract_string},
    },
};
use sxd_xpath::nodeset::Node;

fn vote_response_key(id: &PostId) -> String {
    format!("/topic/{}/post/{}/vote_response", id.tid, id.pid)
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
        .get_msg_async::<PostVoteResponse>(&vote_response_key(&post_id))
        .ok()
        .flatten()
        .map(|r| r.state)
        .unwrap_or(VoteState::NONE);

    let post = Post {
        id: Some(post_id).into(),
        floor: get!(map, "lou", u32)?,
        author_id: get!(map, "authorid")?,
        content: Some(content).into(),
        post_date: get!(map, "postdatetimestamp", _)?,
        score: get!(map, "score", _)?,
        vote_state,
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

    if let Ok(delta) = extract_string(&package, "/root/data/item[2]") {
        let delta = delta.parse::<i32>().unwrap_or_default();
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
        let _ = CACHE.insert_msg_async(&vote_response_key(request.get_post_id()), response.clone());
        Ok(response)
    } else {
        let error = extract_string(&package, "/root/error/item[1]").unwrap_or_default();
        Ok(PostVoteResponse {
            _error: Some(error).map(PostVoteResponse_oneof__error::error),
            ..Default::default()
        })
    }
}

#[cfg(test)]
mod test {
    use super::*;
    use crate::protos::DataModel::PostId;

    #[tokio::test]
    async fn test_post_vote() -> LogicResult<()> {
        use PostVoteRequest_Operation::*;
        let vote = |op| {
            post_vote(PostVoteRequest {
                post_id: Some(PostId {
                    tid: "27375475".to_owned(),
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
