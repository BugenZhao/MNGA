use self::{parser::parse_to_spans, post_process::post_process};
use crate::{error::LogicResult, protos::DataModel::Span};

mod parser;
mod post_process;

pub fn parse(text: &str) -> LogicResult<Vec<Span>> {
    let text = html_escape::decode_html_entities(text);
    let mut spans = parse_to_spans(&text)?;
    post_process(&mut spans);
    Ok(spans)
}
