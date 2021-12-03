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
    #[error("{} ({})", .0.get_info(), .0.get_code())]
    Nga(ErrorMessage),
    #[error("{} ({})", .0.get_info(), .0.get_code())]
    Mnga(ErrorMessage),
    #[error("{0}")]
    MissingField(String),

    #[error(transparent)]
    Reqwest(#[from] reqwest::Error),
    #[error(transparent)]
    XmlParse(#[from] sxd_document::parser::Error),
    #[error(transparent)]
    JsonParse(#[from] serde_json::Error),
    #[error(transparent)]
    XPath(#[from] sxd_xpath::Error),
    #[error(transparent)]
    Cache(#[from] cache::CacheError),
    #[error(transparent)]
    TextParse(#[from] text::error::ParseError),
    #[error(transparent)]
    UrlParse(#[from] url::ParseError),
    #[error(transparent)]
    Protobuf(#[from] protos::ProtobufError),

    #[error("{0}")]
    Panic(String),
}

impl ServiceError {
    fn to_kind(&self) -> &'static str {
        match self {
            ServiceError::Nga(_) => "NGA",
            ServiceError::Mnga(_) => "MNGA",
            ServiceError::MissingField(_) => "Missing Field",
            ServiceError::Reqwest(_) => "Network Connection",
            ServiceError::XmlParse(_) => "XML Parse",
            ServiceError::JsonParse(_) => "JSON Parse",
            ServiceError::XPath(_) => "XPath Resolve",
            ServiceError::Cache(_) => "Cache",
            ServiceError::TextParse(_) => "Text Parse",
            ServiceError::UrlParse(_) => "URL Parse",
            ServiceError::Protobuf(_) => "Protocol Buffer Encoding",
            ServiceError::Panic(_) => "Backend Panic",
        }
    }

    pub fn to_app_string(&self) -> String {
        format!("{}|{}", self.to_kind(), self)
    }
}

pub type ServiceResult<T> = Result<T, ServiceError>;
