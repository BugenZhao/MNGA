use crate::{DataModel::PostReplyAction_Operation, Service::PostVoteRequest_Operation};

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
            &PostReplyAction_Operation::COMMENT => "reply",
        }
    }
}
