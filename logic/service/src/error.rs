use protos::DataModel::ErrorMessage;
use std::any;
use thiserror::Error;

pub fn any_err_to_string(e: Box<dyn any::Any + Send>) -> String {
    e.downcast_ref::<Box<dyn ToString>>()
        .map_or("<unknown>".into(), |e| e.to_string())
}

#[allow(dead_code)]
#[derive(Error, Debug)]
pub enum ServiceError {
    #[error("NGA: {} ({})", .0.get_info(), .0.get_code())]
    Nga(ErrorMessage),
    #[error("Missing field: {0}")]
    MissingField(String),

    #[error(transparent)]
    Reqwest(#[from] reqwest::Error),
    #[error(transparent)]
    XmlParse(#[from] sxd_document::parser::Error),
    #[error(transparent)]
    XPath(#[from] sxd_xpath::Error),
    #[error(transparent)]
    Cache(#[from] cache::CacheError),
    #[error(transparent)]
    Parse(#[from] text::error::ParseError),

    #[error("panic: {0}")]
    Panic(String),
}

pub type ServiceResult<T> = Result<T, ServiceError>;
