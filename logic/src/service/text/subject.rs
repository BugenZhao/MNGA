use crate::error::{LogicError, LogicResult};

peg::parser! {
    grammar subject_parser() for str {
        rule any_char() = [_]
        rule ws() = [' ' | '\t' | '\r' | '\n']
        rule _() = ws()*
        rule left_bracket() = "[" / "【"
        rule right_bracket() = "]" / "】"
        rule bracket() = left_bracket() / right_bracket()

        rule tag() -> &'input str
            = left_bracket() t:$( (!bracket() any_char())+ ) right_bracket() { t.trim() }
        rule content() -> &'input str
            = s:$( any_char()* ) { s.trim() }

        pub rule subject() -> (Vec<&'input str>, &'input str)
            = _ ts:(tag() ** _) _ c:content() _ { (ts, c) }
    }
}

pub fn do_parse_subject(full: &str) -> LogicResult<(Vec<&str>, &str)> {
    subject_parser::subject(full).map_err(|e| LogicError::SubjectParse(e.to_string()))
}

#[cfg(test)]
mod test {
    use super::*;

    #[test]
    fn test_works() {
        let text = " [ 讨论]  【树洞] 测试【标题】[[[233";
        let r = do_parse_subject(text).unwrap();
        println!("{:#?}", r);
    }
}
