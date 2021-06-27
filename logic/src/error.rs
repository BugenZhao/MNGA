use std::any;
use thiserror::Error;

pub fn any_err_to_string(e: Box<dyn any::Any + Send>) -> String {
    e.downcast_ref::<Box<dyn ToString>>()
        .map_or("<unknown>".into(), |e| e.to_string())
}

#[derive(Error, Debug)]
pub enum LogicError {
    #[error(transparent)]
    Reqwest(#[from] reqwest::Error),
    #[error(transparent)]
    Parse(#[from] sxd_document::parser::Error),
    #[error(transparent)]
    XPath(#[from] sxd_xpath::Error),
}

pub type LogicResult<T> = Result<T, LogicError>;
