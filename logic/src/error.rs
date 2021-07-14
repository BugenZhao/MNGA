use crate::{cache::CacheError, protos::DataModel::ErrorMessage};
use std::any;
use thiserror::Error;

pub fn any_err_to_string(e: Box<dyn any::Any + Send>) -> String {
    e.downcast_ref::<Box<dyn ToString>>()
        .map_or("<unknown>".into(), |e| e.to_string())
}

#[allow(dead_code)]
#[derive(Error, Debug)]
pub enum LogicError {
    #[error("NGA: {}", .0.get_info())]
    Nga(ErrorMessage),
    #[error("missing field: {0}")]
    MissingField(String),
    #[error("error while paring content: {0}")]
    ContentParse(String),
    #[error("error while paring subject: {0}")]
    SubjectParse(String),

    #[error(transparent)]
    Reqwest(#[from] reqwest::Error),
    #[error(transparent)]
    XmlParse(#[from] sxd_document::parser::Error),
    #[error(transparent)]
    XPath(#[from] sxd_xpath::Error),
    #[error(transparent)]
    Cache(#[from] CacheError),

    #[error("panic: {0}")]
    Panic(String),
}

pub type LogicResult<T> = Result<T, LogicError>;
