use content::do_parse_content;
use protos::DataModel::{PostContent, Span, Span_Plain, Span_oneof_value, Subject};
use subject::do_parse_subject;

use crate::error::ParseError;

mod content;
pub mod error;
mod subject;

pub fn unescape(text: &str) -> String {
    // todo: Cow
    let first = html_escape::decode_html_entities(text);
    let second = html_escape::decode_html_entities(&first).into_owned();
    second
}

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
    let (tags, content) = do_parse_subject(&text)
        .map(|(ts, c)| (ts.into_iter().map(|t| t.to_owned()).collect(), c.to_owned()))
        .unwrap_or_else(|_| (vec![], text));

    Subject {
        tags: tags.into(),
        content,
        ..Default::default()
    }
}

#[cfg(test)]
mod test {
    use super::*;

    #[test]
    fn test_unescape() {
        let text = "&amp;#128514;&amp;#128513;";
        let unescaped = unescape(text);
        println!("{}", unescaped);
        assert_eq!(unescaped, "😂😁");
    }
}
