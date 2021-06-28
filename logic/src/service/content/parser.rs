// use super::ast::Span;
use crate::error::{LogicError, LogicResult};
use crate::protos::DataModel::*;

macro_rules! span_of {
    ($e:expr) => {{
        use Span_oneof_value::*;
        Span {
            value: Some($e),
            ..Default::default()
        }
    }};
}

peg::parser! {
    grammar content_parser() for str {
        rule any_char() = [_]
        rule digit() = ['0'..='9']
        rule alpha() = ['a'..='z' | 'A'..='Z' | '_']
        rule aldig() = alpha() / digit()
        rule left_bracket() = "["
        rule right_bracket() = "]"
        rule left_close_bracket() = "[/"
        rule left_sticker_bracket() = "[s:"
        rule equal() = "="
        rule comma() = ","
        rule colon() = ":"
        rule ws() = [' ' | '\t' | '\r' | '\n']
        rule _() = ws()*
        rule br_tag() = "<br/>"

        rule token() -> &'input str
            = $( aldig()+ )
        rule sticker_name() -> &'input str
            = $( (!right_bracket() any_char())+ )
        rule attributes() -> Vec<&'input str> = equal() ts:(token() ** comma()) { ts }

        rule start_tag() -> (&'input str, Vec<&'input str>) =
            left_bracket() t:token() a:attributes()? right_bracket() {
                (t, a.unwrap_or_default())
            }
        rule close_tag() -> &'input str
            = left_close_bracket() t:token() right_bracket() { t }

        rule plain_text() -> &'input str
            = $( (!(start_tag() / close_tag() / br_tag()) any_char())+ )

        rule tagged() -> Span
            = st:start_tag() s:(span()*) ct:close_tag() {?
                let (start_tag, attributes) = st;
                if start_tag != ct { return Err("mismatched close tag"); }
                let attributes = attributes.into_iter().map(|s| s.to_owned()).collect();

                Ok(span_of!(tagged(Span_Tagged {
                    tag: start_tag.to_owned(),
                    attributes,
                    spans: s.into(),
                    ..Default::default()
                })))
            }
        rule sticker() -> Span
            = left_sticker_bracket() n:sticker_name() right_bracket() {
                span_of!(sticker(Span_Sticker {
                    name: n.to_owned(),
                    ..Default::default()
                }))
            }
        rule br() -> Span
            = br_tag() {
                span_of!(break_line(Span_BreakLine {
                    ..Default::default()
                }))
            }
        rule plain() -> Span
            = pt:plain_text() {
                span_of!(plain(Span_Plain {
                    text: pt.to_owned(),
                    ..Default::default()
                }))
            }

        rule span() -> Span
            = _ s:(tagged() / sticker() / br() / plain()) _ { s }

        pub rule content() -> Vec<Span>
            = ss:(span())* { ss }
    }
}

pub fn parse_to_spans(text: &str) -> LogicResult<Vec<Span>> {
    content_parser::content(text).map_err(|e| LogicError::ContentParse(e.to_string()))
}

#[cfg(test)]
mod test {
    use super::*;

    #[test]
    fn test_quote() {
        let text = r#"
[quote]
[pid=527975334,27383949,1]Reply[/pid]
[b]Post by [uid=2176512]雲天青[/uid] (2021-06-28 16:29):[/b]
<br/><br/>
假如那帖子是真实的，我是纳闷就那样的脑子，这女的是怎么考上公务员的？？？
[/quote]
<br/><br/>
公务员只要脑子聪明会做题会面试，就可以了，说不定人家进来就打算放飞自我了
        "#;
        let r = parse_to_spans(text).unwrap();
        println!("{:#?}", r);
    }

    #[test]
    fn test_img() {
        let text = r#"
我们这男的还一般不让穿短裤凉鞋呢
[img]http://img.nga.178.com/attachments/mon_201209/14/-47218_5052bc587c6f9.png[/img]
虽说没有明确规定，但是理由是领导觉得影响不好，说到底还是一个形象问题吧
        "#;
        let r = parse_to_spans(text).unwrap();
        println!("{:#?}", r);
    }

    #[test]
    fn test_sticker() {
        let text = r#"
2K给nga多少钱[s:a2:不明觉厉]
        "#;
        let r = parse_to_spans(text).unwrap();
        println!("{:#?}", r);
    }

    #[test]
    fn test_br() {
        let text = r#"
Hello world
<br/>
[img]233[/img]
<br/>
Hello world
<br/>
        "#;
        let r = parse_to_spans(text).unwrap();
        println!("{:#?}", r);

        let contains_br = r
            .into_iter()
            .filter(|span| span.has_plain())
            .any(|span| span.get_plain().get_text().contains("<br/>"));
        assert!(!contains_br);
    }

    #[test]
    fn test_bad_bracket() {
        let text = r#"
[quote]
[pid=528051563,27386376,1]Reply[/pid] [b]Post by [uid=63303812]拔刀斋主人[/uid] (2021-06-28 22:05):[/b]
<br/><br/>
你非要挑一个国家最烂的地方拍的话<br/>我去内陆8线小县城分分钟拍出个更破的
[/quote]
<br/><br/>
费城街道上的[人]与电视剧行尸走肉里面一模一样
<br/><br/>
狗眼睁大一点。
<br/><br/>
还有，我现在就坐在成都贫民窟，这里收破烂的精气神都比你的狗爹强。
        "#;
        let r = parse_to_spans(text).unwrap();
        println!("{:#?}", r);

        let contains_br = r
            .into_iter()
            .filter(|span| span.has_plain())
            .any(|span| span.get_plain().get_text().contains("<br/>"));
        assert!(!contains_br);
    }
}
