use std::cmp::Reverse;

use crate::{
    error::{LogicError, LogicResult},
    protos::{DataModel::*, Service::*},
    service::{
        constants::FORUM_ICON_PATH,
        fetch_package,
        forum::{make_fid, make_stid},
        history::insert_topic_history,
        post::extract_post,
        text,
        user::extract_user_and_cache,
        utils::{
            extract_kv, extract_kv_pairs, extract_node, extract_nodes, extract_pages,
            extract_string,
        },
    },
};
use chrono::{Duration, Utc};
use futures::TryFutureExt;
use sxd_xpath::nodeset::Node;

fn extract_topic(node: Node) -> Option<Topic> {
    use super::macros::get;
    let map = extract_kv(node);

    let subject_full = get!(map, "subject").map(|s| text::unescape(&s))?;
    let (tags, subject_content) = text::parse_subject(&subject_full).ok()?;

    let topic = Topic {
        id: get!(map, "tid")?,
        tags: tags.into(),
        subject_content,
        author_id: get!(map, "authorid")?,
        author_name: get!(map, "author")?,
        post_date: get!(map, "postdate", _)?,
        last_post_date: get!(map, "lastpost", _)?,
        replies_num: get!(map, "replies", _)?,
        ..Default::default()
    };

    Some(topic)
}

fn extract_subforum(node: Node, use_fid: bool) -> Option<Subforum> {
    use super::macros::pget;
    let pairs = extract_kv_pairs(node);

    let id = pget!(pairs, 0)?;
    let icon_url = format!("{}/{}.png", FORUM_ICON_PATH, id);

    let id = if use_fid { make_fid(id) } else { make_stid(id) };

    let forum = Forum {
        name: pget!(pairs, 1)?,
        info: pget!(pairs, 2).unwrap_or_default(),
        icon_url,
        id: Some(id).into(),
        ..Default::default()
    };

    let attributes = pget!(pairs, 4, u64).unwrap_or(0);

    let subforum = Subforum {
        forum: Some(forum).into(),
        filter_id: pget!(pairs, 3).unwrap_or_default(), // for filter, subforum id ??
        attributes,
        filterable: attributes > 40,
        ..Default::default()
    };

    Some(subforum)
}

pub async fn get_topic_list(request: TopicListRequest) -> LogicResult<TopicListResponse> {
    let id = request.id.unwrap();
    let package = fetch_package(
        "thread.php",
        vec![
            if id.has_stid() {
                ("stid", id.get_stid())
            } else {
                ("fid", id.get_fid())
            },
            ("page", &request.page.to_string()),
        ],
        vec![],
    )
    .await?;

    let topics = extract_nodes(&package, "/root/__T/item", |ns| {
        ns.into_iter().filter_map(extract_topic).collect()
    })?;

    let pages = extract_pages(&package, "/root/__ROWS", "/root/__T__ROWS_PAGE", 35)?;

    // NONSENSE fields
    //
    // let _selected_subforum_ids = extract_string(&package, "/root/__F/__SELECTED_FORUM")?
    //     .split(',')
    //     .map(|s| s.to_owned())
    //     .collect::<HashSet<_>>();

    let subforums = {
        let mut subforums = extract_nodes(&package, "/root/__F/sub_forums/*", |ns| {
            ns.into_iter()
                .filter_map(|node| {
                    let use_fid = node.expanded_name()?.local_part() == "item";
                    extract_subforum(node, use_fid)
                })
                .collect()
        })?;
        subforums.iter_mut().for_each(|s| {
            // how can I fucking know this ??
            s.selected = [7, 558, 542, 2606, 2590, 4654].contains(&s.get_attributes())
        });

        if request.sort_subforums {
            subforums.sort_by(|a, b| {
                a.get_filterable().cmp(&b.get_filterable()).then(
                    a.get_selected()
                        .cmp(&b.get_selected())
                        .reverse()
                        .then(a.get_forum().get_name().cmp(b.get_forum().get_name())),
                )
            });
        }

        subforums
    };

    let fid = extract_string(&package, "/root/__F/fid")?;
    let id = make_fid(fid);

    let forum = Forum {
        id: Some(id).into(),
        name: extract_string(&package, "/root/__F/name")?,
        ..Default::default()
    };

    Ok(TopicListResponse {
        forum: Some(forum).into(),
        topics: topics.into(),
        pages,
        subforums: subforums.into(),
        ..Default::default()
    })
}

pub async fn get_hot_topic_list(request: HotTopicListRequest) -> LogicResult<HotTopicListResponse> {
    let fetch_page_limit = request.get_fetch_page_limit().max(10);
    let start_timestamp = (Utc::now()
        - match request.get_range() {
            HotTopicListRequest_DateRange::DAY => Duration::days(1),
            HotTopicListRequest_DateRange::WEEK => Duration::days(7),
            HotTopicListRequest_DateRange::MONTH => Duration::days(30),
        })
    .timestamp() as u64;
    let limit = request.get_limit().max(30) as usize;

    let futures = (1..=fetch_page_limit)
        .map(|page| {
            let request = TopicListRequest {
                id: request.id.clone(),
                page,
                ..Default::default()
            };
            get_topic_list(request).map_ok(|r| r.topics.into_vec())
        })
        .collect::<Vec<_>>();
    let responses = futures::future::join_all(futures).await;

    let mut topics = responses
        .into_iter()
        .filter_map(|ts| ts.ok())
        .flatten()
        .filter(|t| t.get_post_date() > start_timestamp)
        .collect::<Vec<_>>();

    topics.sort_by_key(|t| Reverse(t.get_replies_num()));
    let _ = topics.split_off(limit.min(topics.len()));

    Ok(HotTopicListResponse {
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
        vec![],
    )
    .await?;

    let _users = extract_nodes(&package, "/root/__U/item", |ns| {
        ns.into_iter().filter_map(extract_user_and_cache).collect()
    })?;

    let replies = extract_nodes(&package, "/root/__R/item", |ns| {
        ns.into_iter().filter_map(extract_post).collect()
    })?;

    let topic = extract_node(&package, "/root/__T", extract_topic)?
        .flatten()
        .ok_or(LogicError::MissingField("topic".to_owned()))?;

    let pages = extract_pages(&package, "/root/__ROWS", "/root/__R__ROWS_PAGE", 20)?;

    if request.page == 1 {
        insert_topic_history(topic.clone());
    }

    Ok(TopicDetailsResponse {
        topic: Some(topic).into(),
        replies: replies.into(),
        pages,
        ..Default::default()
    })
}

#[cfg(test)]
mod test {
    use super::{super::user::UserController, *};

    #[tokio::test]
    async fn test_topic_list() -> LogicResult<()> {
        let id = make_fid("315".to_owned());
        let response = get_topic_list(TopicListRequest {
            id: Some(id).into(),
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
            topic_id: "27477718".to_owned(),
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

    #[tokio::test]
    async fn test_hot_topic_list() -> LogicResult<()> {
        let id = make_fid("-7".to_owned());
        let response = get_hot_topic_list(HotTopicListRequest {
            id: Some(id).into(),
            range: HotTopicListRequest_DateRange::DAY,
            ..Default::default()
        })
        .await?;

        println!("response: {:?}", response);

        assert!(!response.get_topics().is_empty());

        Ok(())
    }
}
