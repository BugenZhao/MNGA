use content::do_parse_content;
use protos::DataModel::{PostContent, Span, Span_Plain, Span_oneof_value, Subject};
use subject::do_parse_subject;

use crate::error::ParseError;

mod content;
mod escape;
pub mod error;
mod subject;
pub use escape::{escape_for_submit, unescape};

pub fn parse_content(text: &str) -> PostContent {
    let text = unescape(text).replace('\n', "<br/>");

    let (spans, error) = match do_parse_content(&text) {
        Ok(spans) => (spans, None),
        Err(ParseError::Content(error)) => {
            let fallback_spans = vec![Span {
                value: Some(Span_oneof_value::plain(Span_Plain {
                    text: text.replace("<br/>", "\n"), // todo: extract plain text
                    ..Default::default()
                })),
                ..Default::default()
            }];
            (fallback_spans, Some(error))
        }
        Err(_) => unreachable!(),
    };

    PostContent {
        spans: spans.into(),
        raw: text,
        error: error.unwrap_or_default(),
        ..Default::default()
    }
}

pub fn parse_subject(text: &str) -> Subject {
    let text = unescape(text);
    let (mut tags, mut content) = do_parse_subject(&text)
        .map(|(ts, c)| (ts.into_iter().map(|t| t.to_owned()).collect(), c.to_owned()))
        .unwrap_or_else(|_| (vec![], text));

    // Use last tag as content if content is empty.
    if content.is_empty()
        && let Some(last_tag) = tags.pop()
    {
        content = format!("【{}】", last_tag);
    }

    Subject {
        tags: tags.into(),
        content,
        ..Default::default()
    }
}
