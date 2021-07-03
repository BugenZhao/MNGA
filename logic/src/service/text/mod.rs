use self::{content::do_parse_content, subject::do_parse_subject};
use crate::{error::LogicResult, protos::DataModel::Span};
use std::borrow::Cow;

mod content;
mod subject;

pub fn unescape(text: &str) -> Cow<str> {
    html_escape::decode_html_entities(text)
}

pub fn parse_content(text: &str) -> LogicResult<Vec<Span>> {
    let text = unescape(text);
    let spans = do_parse_content(&text)?;
    Ok(spans)
}

pub fn parse_subject(text: &str) -> LogicResult<(Vec<String>, String)> {
    let text = unescape(text);
    let result = do_parse_subject(&text)
        .map(|(ts, c)| (ts.into_iter().map(|t| t.to_owned()).collect(), c.to_owned()))
        .unwrap_or_else(|_| (vec![], text.into_owned()));
    Ok(result)
}
