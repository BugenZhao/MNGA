use thiserror::Error;

#[allow(dead_code)]
#[derive(Error, Debug)]
pub enum ParseError {
    #[error("error while parsing content: {0}")]
    Content(String),
    #[error("error while parsing subject: {0}")]
    Subject(String),
}

pub type ParseResult<T> = Result<T, ParseError>;
