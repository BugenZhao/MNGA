use protos::DataModel::ErrorMessage;
use reqwest::StatusCode;
use std::any;
use thiserror::Error;

/// Turns a panic payload into a message. `panic!` and `unwrap` produce a `&'static str` or a
/// `String`.
pub fn any_err_to_string(e: Box<dyn any::Any + Send>) -> String {
    if let Some(s) = e.downcast_ref::<&'static str>() {
        (*s).to_owned()
    } else if let Some(s) = e.downcast_ref::<String>() {
        s.clone()
    } else {
        "<unknown>".into()
    }
}

#[allow(dead_code)]
#[derive(Error, Debug)]
pub enum ServiceError {
    #[error("{0}")]
    MngaInternal(String),

    #[error("{}", .0)]
    Status(ErrorMessage),
    #[error("{}", .0)]
    Nga(ErrorMessage),
    #[error("{0}")]
    MissingField(String),

    #[error(transparent)]
    Reqwest(#[from] reqwest::Error),
    #[error(transparent)]
    XmlParse(#[from] sxd_document::parser::Error),
    #[error(transparent)]
    JsonParse(#[from] serde_json::Error),
    // #[error(transparent)]
    // XmlToJson(#[from] quick_xml::se::SeError),
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
            ServiceError::MngaInternal(_) => "MNGA",
            ServiceError::Status(_) => "Error Response",
            ServiceError::Nga(_) => "NGA",
            ServiceError::MissingField(_) => "Missing Field",
            ServiceError::Reqwest(_) => "Network Connection",
            ServiceError::XmlParse(_) /* | ServiceError::XmlToJson(_) */ => "XML Parse",
            ServiceError::JsonParse(_) => "JSON Parse",
            ServiceError::XPath(_) => "XPath Resolve",
            ServiceError::Cache(_) => "Cache",
            ServiceError::TextParse(_) => "Text Parse",
            ServiceError::UrlParse(_) => "URL Parse",
            ServiceError::Protobuf(_) => "Protocol Buffer Encoding",
            ServiceError::Panic(_) => "Backend Panic",
        }
    }

    /// Create a `ServiceError::Status` from `reqwest::StatusCode`.
    pub fn from_status(status: StatusCode) -> Self {
        ServiceError::Status(ErrorMessage {
            code: status.as_u16().to_string(),
            info: status.canonical_reason().unwrap_or_default().to_owned(),
            ..Default::default()
        })
    }

    pub fn to_app_string(&self) -> String {
        format!("{}|{}", self.to_kind(), self)
    }

    /// Whether the error is caused by response parse error. If so, it's likely to be NGA blocking.
    pub fn is_response_parse_error(&self) -> bool {
        matches!(self, ServiceError::XmlParse(_) | ServiceError::JsonParse(_))
    }
}

pub type ServiceResult<T> = Result<T, ServiceError>;

#[cfg(test)]
mod test {
    use super::*;

    #[test]
    fn test_any_err_to_string() {
        let message = |f: fn()| any_err_to_string(std::panic::catch_unwind(f).unwrap_err());

        assert_eq!(message(|| panic!("static")), "static");
        assert_eq!(message(|| panic!("formatted {}", 1)), "formatted 1");
        assert_eq!(
            message(|| {
                "x".parse::<u8>().unwrap();
            }),
            "called `Result::unwrap()` on an `Err` value: ParseIntError { kind: InvalidDigit }"
        );
        assert_eq!(message(|| std::panic::panic_any(42)), "<unknown>");
    }
}
