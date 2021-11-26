use anyhow::Result;
use protos::{
    DataModel::{Device, Forum, ForumId, ForumId_oneof_id, Post, PostId, Topic, UserName},
    Service::{TopicDetailsRequest, TopicDetailsResponse, TopicListRequest, TopicListResponse},
};
use serde::{Deserialize, Serialize};

use crate::utils::get_unique_id;
use crate::{
    render::{Render, Renderer},
    utils::now,
};

#[derive(Debug, Serialize, Deserialize)]
pub struct MockPost {
    #[serde(skip, default = "get_unique_id")]
    pub id: String,

    pub content: String,
    pub author: String,
}

impl MockPost {
    fn to_model(&self, tid: &str, floor: u32) -> Post {
        let content = text::parse_content(&self.content);
        let id = PostId {
            pid: (if floor == 0 { "0" } else { &self.id }).to_owned(),
            tid: tid.to_owned(),
            ..Default::default()
        };

        Post {
            id: Some(id).into(),
            floor,
            content: Some(content).into(),
            post_date: now(),
            score: 233,
            device: Device::APPLE,
            at_page: 1,
            ..Default::default()
        }
    }
}

#[derive(Debug, Serialize, Deserialize)]
pub struct MockTopic {
    #[serde(skip, default = "get_unique_id")]
    pub id: String,

    pub subject: String,
    pub posts: Vec<MockPost>,
}

impl MockTopic {
    fn to_model(&self) -> Topic {
        let subject = text::parse_subject(&self.subject);
        let author = UserName {
            normal: self
                .posts
                .first()
                .map(|p| p.author.to_owned())
                .unwrap_or_default(),
            ..Default::default()
        };

        Topic {
            id: self.id.clone(),
            subject: Some(subject).into(),
            author_id: "".to_owned(),
            author_name: Some(author).into(),
            post_date: now(),
            last_post_date: now(),
            replies_num: self.posts.len().saturating_sub(1) as u32,
            ..Default::default()
        }
    }
}

impl Render for MockTopic {
    fn render(&self, renderer: &mut Renderer) -> Result<()> {
        let topic = self.to_model();
        let id = topic.get_id().to_owned();

        let req = TopicDetailsRequest {
            topic_id: id.clone(),
            page: 1,
            ..Default::default()
        };

        let res = TopicDetailsResponse {
            topic: Some(topic).into(),
            replies: self
                .posts
                .iter()
                .enumerate()
                .map(|(i, p)| p.to_model(&id, i as u32))
                .collect(),
            pages: 1,
            ..Default::default()
        };

        renderer.render(&req, &res)?;
        Ok(())
    }
}

#[derive(Debug, Serialize, Deserialize)]
pub struct MockForum {
    #[serde(skip, default = "get_unique_id")]
    pub id: String,

    pub name: String,
    pub topics: Vec<MockTopic>,
}

impl MockForum {
    fn to_model(&self) -> Forum {
        let id = ForumId {
            id: Some(ForumId_oneof_id::fid(self.id.clone())).into(),
            ..Default::default()
        };

        Forum {
            id: Some(id).into(),
            name: self.name.clone(),
            ..Default::default()
        }
    }
}

impl Render for MockForum {
    fn render(&self, renderer: &mut Renderer) -> Result<()> {
        let forum = self.to_model();
        let id = forum.get_id().to_owned();

        let req = TopicListRequest {
            id: Some(id).into(),
            page: 1,
            ..Default::default()
        };

        let res = TopicListResponse {
            forum: Some(forum).into(),
            topics: self.topics.iter().map(MockTopic::to_model).collect(),
            pages: 1,
            ..Default::default()
        };

        renderer.render(&req, &res)?;
        for child in self.topics.iter() {
            child.render(renderer)?;
        }
        Ok(())
    }
}
