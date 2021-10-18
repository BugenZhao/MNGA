use crate::{
    DataModel::{PostReplyAction_Operation, ShortMessagePostAction_Operation},
    Service::{PostVoteRequest_Operation, TopicListRequest_Order},
};

pub trait ToValue {
    fn to_value(&self) -> &'static str;
}

impl ToValue for PostVoteRequest_Operation {
    fn to_value(&self) -> &'static str {
        match self {
            PostVoteRequest_Operation::UPVOTE => "1",
            PostVoteRequest_Operation::DOWNVOTE => "-1",
        }
    }
}

impl ToValue for PostReplyAction_Operation {
    fn to_value(&self) -> &'static str {
        match self {
            PostReplyAction_Operation::REPLY => "reply",
            PostReplyAction_Operation::QUOTE => "quote",
            PostReplyAction_Operation::MODIFY => "modify",
            PostReplyAction_Operation::COMMENT => "reply",
            PostReplyAction_Operation::NEW => "new",
        }
    }
}

impl ToValue for TopicListRequest_Order {
    fn to_value(&self) -> &'static str {
        match self {
            TopicListRequest_Order::LAST_POST => "",
            TopicListRequest_Order::POST_DATE => "postdatedesc",
        }
    }
}

impl ToValue for ShortMessagePostAction_Operation {
    fn to_value(&self) -> &'static str {
        match self {
            ShortMessagePostAction_Operation::REPLY => "reply",
            ShortMessagePostAction_Operation::NEW => "new",
        }
    }
}
