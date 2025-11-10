use protos::{
    DataModel::Post,
    Service::{TopicDetailsRequest, TopicDetailsRequest_WebApiStrategy},
};

use crate::topic::get_topic_details;

async fn do_test(request: TopicDetailsRequest) {
    let xml = {
        let request = TopicDetailsRequest {
            web_api_strategy: TopicDetailsRequest_WebApiStrategy::DISABLED,
            ..request.clone()
        };
        get_topic_details(request).await
    };

    let web = {
        let request = TopicDetailsRequest {
            web_api_strategy: TopicDetailsRequest_WebApiStrategy::ONLY,
            ..request.clone()
        };
        get_topic_details(request).await
    };

    let (mut xml, mut web) = match (xml, web) {
        (Ok(xml), Ok(web)) => (xml, web),
        (Err(xml_e), Err(web_e)) => {
            pretty_assertions::assert_eq!(xml_e.to_app_string(), web_e.to_app_string());
            return;
        }
        (xml, web) => panic!("one succeeded and the other failed\nxml: {xml:?}\nweb: {web:?}"),
    };

    // Normalize the response before comparing.
    for res in [&mut xml, &mut web] {
        res.api_used = "".to_owned();
        res.mut_topic()._replies_num_last_visit = None;
        res.mut_topic()._highest_viewed_floor = None;
        res.mut_topic()._last_viewing_floor = None;

        fn normalize_anonymous_author_id(author_id: &mut String) {
            // There's UUID in anonymous author id, remove it.
            *author_id = author_id.split(",").last().unwrap().to_owned();
        }
        normalize_anonymous_author_id(res.mut_topic().mut_author_id());

        fn normalize_post(post: &mut Post) {
            normalize_anonymous_author_id(post.mut_author_id());
            post.alter_info = "".to_owned(); // FIXME
            post.device = Default::default(); // FIXME

            post.mut_comments().into_iter().for_each(normalize_post);
            post.mut_hot_replies().into_iter().for_each(normalize_post);
        }

        for post in res.mut_replies() {
            normalize_post(post);
        }
    }

    pretty_assertions::assert_eq!(xml, web);
}

// PASSED
#[tokio::test]
async fn test_first_page() {
    do_test(TopicDetailsRequest {
        topic_id: "45510130".to_owned(),
        page: 1,
        ..Default::default()
    })
    .await;
}

// FIXME: missing: post_date
#[tokio::test]
async fn test_subsequent_page() {
    do_test(TopicDetailsRequest {
        topic_id: "45510130".to_owned(),
        page: 2,
        ..Default::default()
    })
    .await;
}

// FIXME: incorrect: post_date, pages
#[tokio::test]
async fn test_specific_post() {
    do_test(TopicDetailsRequest {
        post_id: "531589220".to_owned(),
        ..Default::default()
    })
    .await;
}

// FIXME: incorrect: pages; missing: attachments
#[tokio::test]
async fn test_author_only() {
    do_test(TopicDetailsRequest {
        topic_id: "28454798".to_owned(),
        author_id: "62765271".to_owned(),
        ..Default::default()
    })
    .await;
}

// FIXME: missing: comments; extra: post?
#[tokio::test]
async fn test_anonymous() {
    do_test(TopicDetailsRequest {
        topic_id: "17169610".to_owned(),
        page: 1,
        ..Default::default()
    })
    .await;
}

// PASSED
#[tokio::test]
async fn test_error() {
    do_test(TopicDetailsRequest {
        topic_id: "1".to_owned(),
        ..Default::default()
    })
    .await;
}
