use crate::{
    attachment::extract_attachment,
    error::ServiceResult,
    fetch::fetch_package_multipart,
    fetch_package,
    topic::extract_topic,
    user,
    utils::{
        extract_kv, extract_node_rel, extract_nodes, extract_nodes_rel, extract_string,
        get_unique_id,
    },
};
use cache::CACHE;
use protos::{DataModel::*, Service::*, ToValue};
use reqwest::multipart;
use sxd_xpath::nodeset::Node;
use text::error::ParseError;

fn vote_response_key(id: &PostId) -> String {
    format!("/vote_response/topic/{}/post/{}", id.tid, id.pid)
}

pub fn extract_post_content(raw: String) -> PostContent {
    let (spans, error) = match text::parse_content(&raw) {
        Ok(spans) => (spans, None),
        Err(ParseError::Content(error)) => {
            let fallback_spans = vec![Span {
                value: Some(Span_oneof_value::plain(Span_Plain {
                    text: raw.replace("<br/>", "\n"), // todo: extract plain text
                    ..Default::default()
                })),
                ..Default::default()
            }];
            (fallback_spans, Some(error))
        }
        Err(_) => unreachable!(),
    };

    PostContent {
        spans: spans.into(),
        raw,
        error: error.unwrap_or_default(),
        ..Default::default()
    }
}

pub fn extract_post(node: Node, at_page: u32, context: &str) -> Option<Post> {
    use super::macros::get;
    let map = extract_kv(node);

    let raw_content = get!(map, "content")?;
    let content = extract_post_content(raw_content);

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
        ns.into_iter()
            .filter_map(|n| extract_post(n, 1, context))
            .collect()
    })
    .unwrap_or_default();

    let comments = extract_nodes_rel(node, "./comment/item", |ns| {
        ns.into_iter()
            .filter_map(|n| extract_post(n, 1, context))
            .collect()
    })
    .unwrap_or_default();

    let device = {
        let device = extract_node_rel(node, ".//from_client", |n| n.string_value())
            .ok()
            .flatten()
            .unwrap_or_default()
            .to_lowercase();

        if device.contains("android") {
            Device::ANDROID
        } else if device.contains("ios") {
            Device::APPLE
        } else {
            Device::DESKTOP
        }
    };

    let attachments = extract_nodes_rel(node, "./attachs/item", |ns| {
        ns.into_iter().filter_map(extract_attachment).collect()
    })
    .unwrap_or_default();

    let author_id = {
        let id = get!(map, "authorid")?;
        if id.starts_with("-") {
            user::attach_context_to_id(&id, context)
        } else {
            id
        }
    };

    let post = Post {
        id: Some(post_id).into(),
        floor: get!(map, "lou", u32)?,
        author_id,
        content: Some(content).into(),
        post_date: get!(map, "postdatetimestamp", _)?,
        score: get!(map, "score", _)?,
        vote_state,
        hot_replies: hot_replies.into(),
        comments: comments.into(),
        device,
        alter_info: get!(map, "alterinfo").unwrap_or_default(),
        attachments: attachments.into(),
        fid: get!(map, "fid")?,
        at_page,
        ..Default::default()
    };

    Some(post)
}

fn extract_light_post(node: Node) -> Option<LightPost> {
    use super::macros::get;
    let map = extract_kv(node);

    let raw_content = get!(map, "content")?;
    let content = extract_post_content(raw_content);

    let post_id = PostId {
        pid: get!(map, "pid")?,
        tid: get!(map, "tid")?,
        ..Default::default()
    };

    let post = LightPost {
        id: Some(post_id).into(),
        author_id: get!(map, "authorid")?,
        content: Some(content).into(),
        post_date: get!(map, "postdate", _).unwrap_or_default(),
        ..Default::default()
    };

    Some(post)
}

fn extract_topic_with_light_post(node: Node) -> Option<TopicWithLightPost> {
    let topic = extract_topic(node)?;
    let post = extract_node_rel(node, "./__P", extract_light_post)
        .unwrap_or_default()
        .flatten()?;

    Some(TopicWithLightPost {
        topic: Some(topic).into(),
        post: Some(post).into(),
        ..Default::default()
    })
}

pub async fn post_vote(request: PostVoteRequest) -> ServiceResult<PostVoteResponse> {
    use std::cmp::Ordering::*;
    use PostVoteRequest_Operation::*;

    let value = request.get_operation().to_value();

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

macro_rules! query_insert_id {
    ($query:expr, $request:expr) => {{
        use PostReplyAction_Operation::*;
        match $request.get_action().get_operation() {
            REPLY | QUOTE | MODIFY | COMMENT => {
                $query.push(("tid", $request.get_action().get_post_id().get_tid()));
                $query.push(("pid", $request.get_action().get_post_id().get_pid()));
            }
            NEW => {
                let id = $request.get_action().get_forum_id();
                $query.push(if id.has_stid() {
                    ("stid", id.get_stid())
                } else {
                    ("fid", id.get_fid())
                });
            }
        }
    }};
}

pub async fn post_reply(request: PostReplyRequest) -> ServiceResult<PostReplyResponse> {
    let action = request.get_action().get_operation().to_value();

    let attachments = request
        .get_attachments()
        .iter()
        .map(|a| a.get_name())
        .collect::<Vec<_>>()
        .join("\t");
    let attachments_check = request
        .get_attachments()
        .iter()
        .map(|a| a.get_check())
        .collect::<Vec<_>>()
        .join("\t");

    let query = {
        let mut query = vec![
            ("action", action),
            ("step", "2"),
            ("post_content", request.get_content()),
            ("attachments", &attachments),
            ("attachments_check", &attachments_check),
        ];
        if request.has_subject() {
            query.push(("post_subject", request.get_subject()));
        }
        if request.get_action().get_operation() == PostReplyAction_Operation::COMMENT {
            query.push(("comment", "1"));
        }
        if request.get_action().get_operation() == PostReplyAction_Operation::MODIFY
            && request.get_action().get_verbatim().get_modify_append()
        {
            query.push(("modify_append", "1"));
        }
        query_insert_id!(query, request);
        query
    };

    let _package = fetch_package("post.php", query, vec![]).await?;

    Ok(PostReplyResponse::new())
}

pub async fn post_reply_fetch_content(
    request: PostReplyFetchContentRequest,
) -> ServiceResult<PostReplyFetchContentResponse> {
    let action = request.get_action().get_operation().to_value();

    let query = {
        let mut query = vec![
            ("action", action),
            ("tid", request.get_action().get_post_id().get_tid()),
            ("pid", request.get_action().get_post_id().get_pid()),
        ];
        query_insert_id!(query, request);
        query
    };

    let package = fetch_package("post.php", query, vec![]).await?;

    let content = extract_string(&package, "/root/content").unwrap_or_default();
    let subject = extract_string(&package, "/root/subject")
        .ok()
        .filter(|s| !s.is_empty());

    let modify_append = !extract_string(&package, "/root/modify_append")
        .unwrap_or_default()
        .is_empty();
    let auth = extract_string(&package, "/root/auth").unwrap_or_default();
    let attach_url = extract_string(&package, "/root/attach_url").unwrap_or_default();
    let verbatim = PostReplyVerbatim {
        modify_append,
        auth,
        attach_url,
        ..Default::default()
    };

    Ok(PostReplyFetchContentResponse {
        content,
        _subject: subject.map(PostReplyFetchContentResponse_oneof__subject::subject),
        verbatim: Some(verbatim).into(),
        ..Default::default()
    })
}

pub async fn upload_attachment(
    mut request: UploadAttachmentRequest,
) -> ServiceResult<UploadAttachmentResponse> {
    let action = request.take_action();
    let file = request.take_file();
    let name = format!("{}.jpeg", get_unique_id());

    let query = vec![];

    let form = multipart::Form::new()
        .text("v2", "1")
        .text("origin_domain", "ngabbs.com") // todo: original domain
        .text("func", "upload")
        .text("auth", action.get_verbatim().get_auth().to_owned())
        .text("fid", action.get_forum_id().get_fid().to_owned())
        .text("attachment_file1_img", "1")
        .text("attachment_file1_dscp", name.clone())
        .text("attachment_file1_url_utf8_name", name.clone())
        .text("attachment_file1_watermark", "")
        .text("attachment_file1_auto_size", "")
        .part(
            "attachment_file1",
            multipart::Part::bytes(file)
                .file_name(name.clone())
                .mime_str(&"image/jpeg")
                .unwrap(),
        );

    let package =
        fetch_package_multipart(action.get_verbatim().get_attach_url(), query, form).await?;

    let name = extract_string(&package, "/root/attachments")?;
    let url = extract_string(&package, "/root/url")?;
    let check = extract_string(&package, "/root/attachments_check")?;

    let attachment = PostAttachment {
        name,
        url,
        check,
        ..Default::default()
    };

    Ok(UploadAttachmentResponse {
        attachment: Some(attachment).into(),
        ..Default::default()
    })
}

pub async fn get_user_post_list(
    request: UserPostListRequest,
) -> ServiceResult<UserPostListResponse> {
    let package = fetch_package(
        "thread.php",
        vec![
            ("searchpost", "1"),
            ("authorid", &request.get_author_id()),
            ("page", &request.page.to_string()),
        ],
        vec![],
    )
    .await?;

    let tps = extract_nodes(&package, "/root/__T/item", |ns| {
        ns.into_iter()
            .filter_map(extract_topic_with_light_post)
            .collect()
    })?;

    Ok(UserPostListResponse {
        tps: tps.into(),
        ..Default::default()
    })
}

#[cfg(test)]
mod test {
    use crate::forum::{make_fid, make_stid};

    use super::*;
    use protos::DataModel::PostId;

    #[tokio::test]
    #[ignore]
    async fn test_post_vote() -> ServiceResult<()> {
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

    #[tokio::test]
    #[ignore]
    async fn test_post_reply() -> ServiceResult<()> {
        let _response = post_reply(PostReplyRequest {
            action: Some(PostReplyAction {
                operation: PostReplyAction_Operation::REPLY,
                post_id: Some(PostId {
                    pid: "0".to_owned(),
                    tid: "27455825".to_owned(),
                    ..Default::default()
                })
                .into(),
                ..Default::default()
            })
            .into(),
            content: "测试回复 from logic test".to_owned(),
            ..Default::default()
        })
        .await?;

        Ok(())
    }

    #[tokio::test]
    #[ignore]
    async fn test_post_reply_fetch_content() -> ServiceResult<()> {
        let _response = post_reply_fetch_content(PostReplyFetchContentRequest {
            action: Some(PostReplyAction {
                operation: PostReplyAction_Operation::QUOTE,
                post_id: Some(PostId {
                    pid: "0".to_owned(),
                    tid: "27455825".to_owned(),
                    ..Default::default()
                })
                .into(),
                ..Default::default()
            })
            .into(),
            ..Default::default()
        })
        .await?;

        Ok(())
    }

    #[tokio::test]
    #[ignore]
    async fn test_post_new_topic() -> ServiceResult<()> {
        let _response = post_reply(PostReplyRequest {
            action: Some(PostReplyAction {
                operation: PostReplyAction_Operation::NEW,
                forum_id: make_stid("12689291".to_owned()).into(),
                ..Default::default()
            })
            .into(),
            _subject: PostReplyRequest_oneof__subject::subject(
                "测试发帖 from logic test".to_owned(),
            )
            .into(),
            content: "测试内容 from logic test".to_owned(),
            ..Default::default()
        })
        .await?;

        Ok(())
    }

    #[tokio::test]
    #[ignore]
    async fn test_upload_attachment() -> ServiceResult<()> {
        let mut action = PostReplyAction {
            operation: PostReplyAction_Operation::REPLY,
            post_id: Some(PostId {
                pid: "0".to_owned(),
                tid: "28426407".to_owned(),
                ..Default::default()
            })
            .into(),
            forum_id: make_fid("275".to_owned()).into(),
            ..Default::default()
        };

        let fetch_req = PostReplyFetchContentRequest {
            action: Some(action.clone()).into(),
            ..Default::default()
        };

        let mut fetch_res = post_reply_fetch_content(fetch_req).await?;
        action.set_verbatim(fetch_res.take_verbatim());

        let file = reqwest::get(
            "https://img.nga.178.com/attachments/mon_201904/12/-7Q5-gr04K2iT3cSw0-k0.jpg",
        )
        .await?
        .bytes()
        .await?;

        let upload_req = UploadAttachmentRequest {
            action: Some(action).into(),
            file: file.to_vec(),
            ..Default::default()
        };

        let upload_res = upload_attachment(upload_req).await?;
        let attachment = upload_res.get_attachment();

        println!("{:?}", attachment);
        assert!(!attachment.get_url().is_empty());

        Ok(())
    }

    #[tokio::test]
    async fn test_user_post_list() -> ServiceResult<()> {
        let response = get_user_post_list(UserPostListRequest {
            author_id: "23965969".to_owned(),
            page: 1,
            ..Default::default()
        })
        .await?;

        assert!(!response.get_tps().is_empty());

        Ok(())
    }
}
