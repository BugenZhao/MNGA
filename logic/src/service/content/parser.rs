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
        rule attribute() -> &'input str
            = $( (!(right_bracket() / comma()) any_char())* )
        rule attributes() -> Vec<&'input str> = equal() ts:(attribute() ** comma()) { ts }

        rule start_tag() -> (&'input str, Vec<&'input str>) =
            left_bracket() t:token() a:attributes()? right_bracket() {
                (t, a.unwrap_or_default())
            }
        rule close_tag() -> &'input str
            = left_close_bracket() t:token() right_bracket() { t }

        rule plain_text() -> &'input str
            = $( (!(start_tag() / close_tag() / br_tag() / left_sticker_bracket()) any_char())+ )

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
    }

    #[test]
    fn test_url_attribute() {
        let text = r#"
[quote]近期水区流量较大，为保证社区的稳定，我们选择的将冲水时间由3天调整为12小时，恢复时间未知<br/>
为了保证尽可能减少的冲水带来的负面用户体验，同时为了社区子版面更好的发挥应有作用以及更好的发展，
我在此恳请各位在发帖时请根据发帖主题内容选择对应板块发帖<br/><br/>
游记、摄影作品内容请发至[url=https://bbs.nga.cn/thread.php?fid=-8725919][b]小窗视界[/b][/url]<br/>宠物饲养心得及求助、晒照等内容请发至[url=https://bbs.nga.cn/thread.php?fid=-353371][b]萌萌宠物[/b][/url]<br/>烹饪心得及咨询、美食探店等内容请发至[url=https://bbs.nga.cn/thread.php?fid=-608808][b]恩基爱厨艺美食交流[/b][/url]<br/>主机、电脑游戏相关内容请发至[url=https://bbs.nga.cn/thread.php?fid=414][b]游戏综合讨论[/b][/url]<br/>手游相关内容请发至[url=https://bbs.nga.cn/thread.php?fid=428][b]手机 网页游戏综合讨论[/b][/url]<br/>电影、电视剧歌曲及翻唱等内容请发至[url=https://bbs.nga.cn/thread.php?fid=-576177][b]影音讨论区[/b][/url]<br/>小说、网文类内容请发至[url=https://bbs.nga.cn/thread.php?fid=524][b]漩涡书院[/b][/url]<br/>工作、职场人际关系相关内容请发至[url=https://bbs.nga.cn/thread.php?fid=-1459709][b]职场人生[/b][/url]<br/><br/>除此之外，我们也会对部分现有话题类型进行梳理，以更合理的形式对各个子话题版面进行展示，并且开设部分新话题版面，目前股票版、历史版、综合体育版目前在规划中，家装版也打算进行重新装修，对以上版面管理感兴趣的朋友可以私信我进行报名，我们也会对版务团队人选进行审核及筛选。<br/><br/>然后再聊聊水区，近些年来不少用户对于水区质量下降的情况表示不满，鉴于此，我们将考虑重新启用水区博物馆的计划，在不修改水区现有声望体系的情况下对于有质量的科普贴等内容进行威望奖励并不进行冲水，提升水区内容质量。<br/><br/>银色近期会开放 话题、游戏版面or合集新建的申请方式，还请有此方面意向者关注。<br/><br/>感谢各位长久以来的支持和配合！<br/>[img]./mon_202002/11/-7Q5-1fz0XjZ5cT1kS5g-2y.gif.medium.jpg[/img][/quote]
        "#;
        let r = parse_to_spans(text).unwrap();
        println!("{:#?}", r);
    }
}
