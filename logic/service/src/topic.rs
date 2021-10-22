use crate::{
    constants::FORUM_ICON_PATH,
    error::{ServiceError, ServiceResult},
    fetch_package,
    forum::{extract_forum, make_fid, make_stid},
    history::{find_topic_history, insert_topic_history},
    post::extract_post_with_at_page,
    user::extract_user_and_cache,
    utils::{
        extract_kv, extract_kv_pairs, extract_node, extract_node_rel, extract_nodes, extract_pages,
        extract_string,
    },
};
use cache::CACHE;
use chrono::{Duration, Utc};
use futures::TryFutureExt;
use protos::{DataModel::*, Service::*, ToValue};
use std::cmp::Reverse;
use sxd_xpath::nodeset::Node;

fn favor_response_key(topic_id: &str) -> String {
    format!("/favor_response/topic/{}", topic_id)
}

fn topic_details_response_key(request: &TopicDetailsRequest) -> Option<String> {
    if request.get_post_id().is_empty() && request.get_author_id().is_empty() {
        format!(
            "/topic_details_response/topic/{}/page/{}",
            request.get_topic_id(),
            request.get_page()
        )
        .into()
    } else {
        None
    }
}

fn extract_topic_parent_forum(node: Node) -> Option<Forum> {
    use super::macros::get;
    let map = extract_kv(node);

    let fid = get!(map, "_0").map(make_fid).flatten();
    let stid = get!(map, "_1").map(make_stid).flatten();

    let forum = Forum {
        id: stid.or(fid).into(),
        name: get!(map, "_2")?,
        ..Default::default()
    };

    Some(forum)
}

pub fn extract_topic_subject(raw: String) -> Subject {
    let (tags, content) = text::parse_subject(&raw).unwrap_or_else(|_| (vec![], raw));
    Subject {
        tags: tags.into(),
        content,
        ..Default::default()
    }
}

pub fn extract_topic(node: Node) -> Option<Topic> {
    fn extract_fav(url: &str) -> Option<&str> {
        use lazy_static::lazy_static;
        use regex::Regex;
        lazy_static! {
            static ref RE: Regex = Regex::new(r"fav=(?P<fav>[a-fA-F0-9]+)").unwrap();
        }
        RE.captures(url)
            .and_then(|cs| cs.name("fav").map(|m| m.as_str()))
    }

    use super::macros::get;
    let map = extract_kv(node);

    let subject_full = get!(map, "subject").map(|s| text::unescape(&s))?;
    let subject = extract_topic_subject(subject_full);

    let parent_forum = extract_node_rel(node, "./parent", extract_topic_parent_forum)
        .ok()
        .flatten()
        .flatten()
        .map(Topic_oneof__parent_forum::parent_forum);

    let fav = get!(map, "tpcurl")
        .and_then(|s| extract_fav(&s).map(ToOwned::to_owned))
        .map(Topic_oneof__fav::fav);

    let id = get!(map, "tid")?;
    let is_favored = CACHE
        .get_msg::<TopicFavorResponse>(&favor_response_key(&id))
        .ok()
        .flatten()
        .map(|r| r.is_favored)
        .unwrap_or(false);

    let replies_num_last_visit = find_topic_history(&id)
        .map(|s| s.get_topic_snapshot().get_replies_num())
        .map(Topic_oneof__replies_num_last_visit::replies_num_last_visit);

    let fid = get!(map, "fid")?;

    let topic = Topic {
        id,
        subject: Some(subject).into(),
        author_id: get!(map, "authorid").unwrap_or_default(), // fix 0730 bug
        author_name: get!(map, "author").unwrap_or_default(), // fix 0730 bug
        post_date: get!(map, "postdate", _)?,
        last_post_date: get!(map, "lastpost", _)?,
        replies_num: get!(map, "replies", _)?,
        _parent_forum: parent_forum,
        _fav: fav,
        is_favored,
        _replies_num_last_visit: replies_num_last_visit,
        fid,
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
        id: id.into(),
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

pub async fn get_favorite_topic_list(
    request: FavoriteTopicListRequest,
) -> ServiceResult<FavoriteTopicListResponse> {
    let package = fetch_package(
        "thread.php",
        vec![("favor", "1"), ("page", &request.page.to_string())],
        vec![],
    )
    .await?;

    let topics = extract_nodes(&package, "/root/__T/item", |ns| {
        ns.into_iter()
            .filter_map(|node| {
                let topic = extract_topic(node);
                if let Some(ref topic) = topic {
                    let _ = CACHE.insert_msg(
                        &favor_response_key(topic.get_id()),
                        &TopicFavorResponse {
                            is_favored: true,
                            ..Default::default()
                        },
                    );
                }
                topic
            })
            .collect()
    })?;

    let pages = extract_pages(&package, "/root/__ROWS", "/root/__T__ROWS_PAGE", 35)?;

    Ok(FavoriteTopicListResponse {
        topics: topics.into(),
        pages,
        ..Default::default()
    })
}

pub async fn get_topic_list(request: TopicListRequest) -> ServiceResult<TopicListResponse> {
    let package = fetch_package(
        "thread.php",
        vec![
            ("stid", request.get_id().get_stid()),
            ("fid", request.get_id().get_fid()),
            ("page", &request.page.to_string()),
            ("order_by", request.get_order().to_value()),
            ("recommend", request.get_recommended_only().to_value()),
        ],
        vec![],
    )
    .await?;

    let topics = extract_nodes(&package, "/root/__T/item", |ns| {
        ns.into_iter().filter_map(extract_topic).collect()
    })?;

    let pages = extract_pages(&package, "/root/__ROWS", "/root/__T__ROWS_PAGE", 35)?;

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

    let forum = extract_node(&package, "/root/__F", extract_forum)
        .unwrap_or_default()
        .flatten();

    Ok(TopicListResponse {
        forum: forum.into(),
        topics: topics.into(),
        pages,
        subforums: subforums.into(),
        ..Default::default()
    })
}

pub async fn get_hot_topic_list(
    request: HotTopicListRequest,
) -> ServiceResult<HotTopicListResponse> {
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
            get_topic_list(request).map_ok(|r| (r.topics.into_vec(), r.forum))
        })
        .collect::<Vec<_>>();
    let responses = futures::future::join_all(futures).await;

    let forum = responses
        .iter()
        .filter_map(|r| r.as_ref().ok())
        .next()
        .map(|p| p.1.to_owned())
        .unwrap_or_default();

    let mut topics = responses
        .into_iter()
        .filter_map(|r| r.ok().map(|p| p.0))
        .flatten()
        .filter(|t| t.get_post_date() > start_timestamp)
        .collect::<Vec<_>>();

    topics.sort_by_key(|t| Reverse(t.get_replies_num()));
    let _ = topics.split_off(limit.min(topics.len()));

    Ok(HotTopicListResponse {
        topics: topics.into(),
        forum,
        ..Default::default()
    })
}

pub async fn search_topic(request: TopicSearchRequest) -> ServiceResult<TopicSearchResponse> {
    let package = fetch_package(
        "thread.php",
        vec![
            ("fid", request.get_id().get_fid()),
            ("stid", request.get_id().get_stid()),
            ("key", request.get_key()),
            ("recommend", request.get_recommended_only().to_value()),
            ("content", request.get_search_content().to_value()),
        ],
        vec![],
    )
    .await?;

    let topics = extract_nodes(&package, "/root/__T/item", |ns| {
        ns.into_iter().filter_map(extract_topic).collect()
    })?;

    let pages = extract_pages(&package, "/root/__ROWS", "/root/__T__ROWS_PAGE", 35)?;

    Ok(TopicSearchResponse {
        topics: topics.into(),
        pages,
        ..Default::default()
    })
}

pub async fn get_topic_details(
    request: TopicDetailsRequest,
) -> ServiceResult<TopicDetailsResponse> {
    let key = topic_details_response_key(&request);

    if request.get_local_cache() {
        return key
            .and_then(|key| CACHE.get_msg::<TopicDetailsResponse>(&key).ok())
            .flatten()
            .ok_or_else(|| {
                ServiceError::Mnga(ErrorMessage {
                    info: "No local cache found".to_owned(),
                    ..Default::default()
                })
            });
    }

    let package = fetch_package(
        "read.php",
        vec![
            ("tid", request.get_topic_id()),
            ("page", &request.get_page().to_string()),
            ("fav", request.get_fav()),
            ("pid", request.get_post_id()),
            ("authorid", request.get_author_id()),
        ],
        vec![],
    )
    .await?;

    let _users = extract_nodes(&package, "/root/__U/item", |ns| {
        ns.into_iter().filter_map(extract_user_and_cache).collect()
    })?;

    let replies = extract_nodes(&package, "/root/__R/item", |ns| {
        ns.into_iter()
            .filter_map(|n| extract_post_with_at_page(request.page, n))
            .collect()
    })?;

    let topic = extract_node(&package, "/root/__T", extract_topic)?
        .flatten()
        .ok_or_else(|| ServiceError::MissingField("topic".to_owned()))?;

    let forum_name = extract_string(&package, "/root/__F").unwrap_or_default();

    let pages = extract_pages(&package, "/root/__ROWS", "/root/__R__ROWS_PAGE", 20)?;

    insert_topic_history(topic.clone()); // save history

    let response = TopicDetailsResponse {
        topic: Some(topic).into(),
        replies: replies.into(),
        forum_name,
        pages,
        ..Default::default()
    };
    if let Some(key) = key {
        let _ = CACHE.insert_msg(&key, &response);
    }

    Ok(response)
}

pub async fn topic_favor(request: TopicFavorRequest) -> ServiceResult<TopicFavorResponse> {
    let (action, tid_key, is_favored) = match request.get_operation() {
        TopicFavorRequest_Operation::ADD => ("add", "tid", true),
        TopicFavorRequest_Operation::DELETE => ("del", "tidarray", false),
    };

    let _package = fetch_package(
        "nuke.php",
        vec![("__lib", "topic_favor"), ("__act", "topic_favor")],
        vec![
            ("action", action),
            (tid_key, request.get_topic_id()),
            ("page", "1"),
        ],
    )
    .await?;

    let response = TopicFavorResponse {
        is_favored,
        ..Default::default()
    };
    let _ = CACHE.insert_msg(&favor_response_key(request.get_topic_id()), &response);

    Ok(response)
}

pub async fn get_user_topic_list(
    request: UserTopicListRequest,
) -> ServiceResult<UserTopicListResponse> {
    let package = fetch_package(
        "thread.php",
        vec![
            ("authorid", &request.get_author_id()),
            ("page", &request.page.to_string()),
        ],
        vec![],
    )
    .await?;

    let topics = extract_nodes(&package, "/root/__T/item", |ns| {
        ns.into_iter().filter_map(extract_topic).collect()
    })?;

    let pages = extract_pages(&package, "/root/__ROWS", "/root/__T__ROWS_PAGE", 35)?;

    Ok(UserTopicListResponse {
        topics: topics.into(),
        pages,
        ..Default::default()
    })
}

#[cfg(test)]
mod test {
    use super::{super::user::UserController, *};

    #[tokio::test]
    async fn test_topic_list() -> ServiceResult<()> {
        let id = make_fid("315".to_owned());
        let response = get_topic_list(TopicListRequest {
            id: id.into(),
            page: 1,
            ..Default::default()
        })
        .await?;

        println!("response: {:?}", response);
        println!("forum: {:#?}", response.get_forum());

        assert!(!response.get_topics().is_empty());

        Ok(())
    }

    #[tokio::test]
    async fn test_topic_details() -> ServiceResult<()> {
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
    async fn test_hot_topic_list() -> ServiceResult<()> {
        let id = make_fid("-7".to_owned());
        let response = get_hot_topic_list(HotTopicListRequest {
            id: id.into(),
            range: HotTopicListRequest_DateRange::DAY,
            ..Default::default()
        })
        .await?;

        println!("response: {:?}", response);

        assert!(!response.get_topics().is_empty());

        Ok(())
    }

    #[tokio::test]
    async fn test_topic_favor() -> ServiceResult<()> {
        use TopicFavorRequest_Operation::*;

        let post = |op| {
            topic_favor(TopicFavorRequest {
                topic_id: "27455825".to_owned(),
                operation: op,
                ..Default::default()
            })
        };

        post(ADD).await?;
        post(DELETE).await?;

        Ok(())
    }

    #[tokio::test]
    async fn test_specific_post() -> ServiceResult<()> {
        let response = get_topic_details(TopicDetailsRequest {
            post_id: "549031060".to_owned(),
            ..Default::default()
        })
        .await?;

        assert_eq!(response.get_replies().len(), 1);

        Ok(())
    }

    #[tokio::test]
    async fn test_author_only() -> ServiceResult<()> {
        // https://ngabbs.com/read.php?tid=28454798&authorid=62765271
        let author_id = "62765271";

        let response = get_topic_details(TopicDetailsRequest {
            topic_id: "28454798".to_owned(),
            author_id: author_id.to_owned(),
            page: 1,
            ..Default::default()
        })
        .await?;

        assert!(response
            .get_replies()
            .iter()
            .all(|p| p.author_id == author_id));

        Ok(())
    }

    #[tokio::test]
    async fn test_search_topic() -> ServiceResult<()> {
        let id = make_fid("650".to_owned());
        let response = search_topic(TopicSearchRequest {
            id: id.into(),
            page: 1,
            search_content: true,
            key: "钟离".to_owned(),
            ..Default::default()
        })
        .await?;

        println!("response: {:?}", response);

        assert!(!response.get_topics().is_empty());

        Ok(())
    }
}
