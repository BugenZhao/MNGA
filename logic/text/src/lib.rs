use content::do_parse_content;
use error::ParseResult;
use protos::DataModel::Span;
use subject::do_parse_subject;

mod content;
pub mod error;
mod subject;

pub fn unescape(text: &str) -> String {
    // todo: Cow
    let first = html_escape::decode_html_entities(text);
    let second = html_escape::decode_html_entities(&first).into_owned();
    second
}

pub fn parse_content(text: &str) -> ParseResult<Vec<Span>> {
    let text = unescape(text);
    let spans = do_parse_content(&text)?;
    Ok(spans)
}

pub fn parse_subject(text: &str) -> ParseResult<(Vec<String>, String)> {
    let text = unescape(text);
    let result = do_parse_subject(&text)
        .map(|(ts, c)| (ts.into_iter().map(|t| t.to_owned()).collect(), c.to_owned()))
        .unwrap_or_else(|_| (vec![], text));
    Ok(result)
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
