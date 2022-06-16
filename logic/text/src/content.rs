use crate::error::{ParseError, ParseResult};
use protos::DataModel::*;

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
        rule left_bracket() = ['[' | '<']
        rule right_bracket() = [']' | '>']
        rule left_close_bracket() = "[/" / "</"
        rule left_sticker_bracket() = "[s:"
        rule equal() = "="
        rule comma() = ","
        rule colon() = ":"
        rule ws() = [' ' | '\t' | '\r' | '\n']
        rule _() = ws()*
        rule br_tag() = "<br/>" / "[stripbr]"
        rule divider_tag() = "==="

        rule token() -> &'input str
            = $( aldig()+ )
        rule sticker_name() -> &'input str
            = $( (!right_bracket() any_char())+ )
        rule attribute() -> &'input str
            = $( (!(left_bracket() / right_bracket() / comma()) any_char())* )
        rule attributes() -> Vec<&'input str>
            = equal() ts:(attribute() ** comma()) { ts }
        rule complex_attrs() -> Vec<&'input str> // "[td rowspan=2 colspan=3]"
            = " " ts:( attribute() ** " " ) { ts }

        rule start_tag() -> (&'input str, Vec<&'input str>, Vec<&'input str>)
            = left_bracket() t:token() a:attributes()? c:complex_attrs()? right_bracket() {
                (t, a.unwrap_or_default(), c.unwrap_or_default())
            }
        rule close_tag() -> &'input str
            = left_close_bracket() t:token() right_bracket() { t }

        rule plain_text() -> &'input str
            = $( (!(start_tag() / close_tag() / br_tag() / left_sticker_bracket() / divider_tag()) any_char())+ )

        rule tagged() -> Span
            = st:start_tag() s:(span()*) ct:close_tag()? {?
                let (start_tag, attributes, complex_attributes) = st;
                // if !start_tag.contains(ct) { return Err("matched close tag"); } // todo: add a flag for this check
                let attributes = attributes.into_iter().map(|s| s.to_owned()).collect();
                let complex_attributes = complex_attributes.into_iter().map(|s| s.to_owned()).collect();

                Ok(span_of!(tagged(Span_Tagged {
                    tag: start_tag.to_owned(),
                    attributes,
                    complex_attributes,
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

        rule divider() -> Span
            = divider_tag() s:(non_divider_span()*) divider_tag() {
                span_of!(tagged(Span_Tagged {
                    tag: "_divider".to_owned(),
                    spans: s.into(),
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

        rule rich() -> Span
            = br() / tagged() / sticker()
        rule non_divider_span() -> Span
            = rich() / plain()  // todo: any better way?
        rule span() -> Span
            = rich() / divider() / plain()

        pub rule content() -> Vec<Span>
            = (span())*
    }
}

pub fn do_parse_content(text: &str) -> ParseResult<Vec<Span>> {
    content_parser::content(text)
        .map_err(|e: peg::error::ParseError<_>| ParseError::Content(e.to_string()))
}

#[cfg(test)]
mod test {
    use super::*;

    #[test]
    fn test_reply_angle_bracket() {
        let text = r#"
        <b>Reply to [pid=618531937,32339526,1]Reply[\/pid] Post by [uid=34387419]熊233[\/uid] (2022-06-16 12:11)<\/b>实付款46是怎么做到的?
        "#;
        let r = do_parse_content(text).unwrap();
        println!("{:#?}", r);
    }

    #[test]
    fn test_reply_square_bracket() {
        let text = r#"
        [b]Reply to [pid=618531937,32339526,1]Reply[/pid] Post by [uid=34387419]熊233[/uid] (2022-06-16 12:11)[/b]实付款46是怎么做到的?
        "#;
        let r = do_parse_content(text).unwrap();
        println!("{:#?}", r);
    }

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
        let r = do_parse_content(text).unwrap();
        println!("{:#?}", r);
    }

    #[test]
    fn test_img() {
        let text = r#"
我们这男的还一般不让穿短裤凉鞋呢
[img]http://img.nga.178.com/attachments/mon_201209/14/-47218_5052bc587c6f9.png[/img]
虽说没有明确规定，但是理由是领导觉得影响不好，说到底还是一个形象问题吧
        "#;
        let r = do_parse_content(text).unwrap();
        println!("{:#?}", r);
    }

    #[test]
    fn test_sticker() {
        let text = r#"
2K给nga多少钱[s:a2:不明觉厉]
        "#;
        let r = do_parse_content(text).unwrap();
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
        let r = do_parse_content(text).unwrap();
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
        let r = do_parse_content(text).unwrap();
        println!("{:#?}", r);
    }

    #[test]
    fn test_url_attribute() {
        let text = r#"
[quote]近期水区流量较大，为保证社区的稳定，我们选择的将冲水时间由3天调整为12小时，恢复时间未知<br/>
为了保证尽可能减少的冲水带来的负面用户体验，同时为了社区子版面更好的发挥应有作用以及更好的发展，
我在此恳请各位在发帖时请根据发帖主题内容选择对应板块发帖<br/><br/>
游记、摄影作品内容请发至[url=https://bbs.nga.cn/thread.php?fid=-8725919]
[b]小窗视界[/b][/url]<br/>宠物饲养心得及求助、晒照等内容请发至[url=https://bbs.nga.cn/thread.php?fid=-353371]
[b]萌萌宠物[/b][/url]<br/>烹饪心得及咨询、美食探店等内容请发至[url=https://bbs.nga.cn/thread.php?fid=-608808]
[b]恩基爱厨艺美食交流[/b][/url]<br/>主机、电脑游戏相关内容请发至[url=https://bbs.nga.cn/thread.php?fid=414]
[b]游戏综合讨论[/b][/url]<br/>手游相关内容请发至[url=https://bbs.nga.cn/thread.php?fid=428]
[b]手机 网页游戏综合讨论[/b][/url]<br/>电影、电视剧歌曲及翻唱等内容请发至[url=https://bbs.nga.cn/thread.php?fid=-576177]
[b]影音讨论区[/b][/url]<br/>小说、网文类内容请发至[url=https://bbs.nga.cn/thread.php?fid=524]
[b]漩涡书院[/b][/url]<br/>工作、职场人际关系相关内容请发至[url=https://bbs.nga.cn/thread.php?fid=-1459709]
[b]职场人生[/b][/url]<br/><br/>
除此之外，我们也会对部分现有话题类型进行梳理，以更合理的形式对各个子话题版面进行展示，
并且开设部分新话题版面，目前股票版、历史版、综合体育版目前在规划中，家装版也打算进行重新装修，
对以上版面管理感兴趣的朋友可以私信我进行报名，我们也会对版务团队人选进行审核及筛选。
<br/><br/>然后再聊聊水区，近些年来不少用户对于水区质量下降的情况表示不满，鉴于此，
我们将考虑重新启用水区博物馆的计划，在不修改水区现有声望体系的情况下对于有质量的科普贴等内容进行威望奖励并不进行冲水，
提升水区内容质量。<br/><br/>银色近期会开放 话题、游戏版面or合集新建的申请方式，还请有此方面意向者关注。
<br/><br/>感谢各位长久以来的支持和配合！<br/>
[img]./mon_202002/11/-7Q5-1fz0XjZ5cT1kS5g-2y.gif.medium.jpg[/img][/quote]
        "#;
        let r = do_parse_content(text).unwrap();
        println!("{:#?}", r);
    }

    #[test]
    fn test_unclosed() {
        let text = r#"
        [quote]
        [tid=27457209]Topic[/tid]
         [b]Post by [uid=63178347]肥宅肥皂[/uid] (2021-07-03 19:36):[/b]
         如果中央真的出这种政策我只想叫好好不好
         [img]./mon_202107/03/-7Q2o-eeg[/quote]
         <br/><br/>同样人均GDP四万多的地方表示公务员年总收入只有赣州一半<br/>而且有些人均GDP七万多的城市和我们收入差不多[s:ac:羡慕]
        "#;
        let r = do_parse_content(text).unwrap();
        println!("{:#?}", r);
    }

    #[test]
    fn test_divider() {
        let texts = [
            r#"======"#,
            r#"===2021-09-08 21:36==="#,
            r#"===[size=150%][color=blue]前言[/color][/size]==="#,
        ];
        for text in texts {
            let r = do_parse_content(text).unwrap();
            println!("{:#?}", r);
        }
    }

    #[test]
    fn test_table_td1_td() {
        let text = r#"
===字体颜色===
<br/>[table]<br/>
[tr]<br/>
[td1][align=center][size=120%][b]颜 色 名[/b][/size][/align][/td]<br/>
[td1][align=center][size=120%][b]范 本[/b][/size][/align][/td]<br/>
[td1][align=center][size=120%][b]粗 体 范 本[/b][/size][/align][/td]<br/>
[td1][align=center][size=120%][b]备 注[/b][/size][/align][/td]
[/tr]<br/>

[tr]<br/>
[td][align=center]默认颜色[/align][/td]<br/>
[td][align=center]默认颜色(无需代码)[/align][/td]<br/>
[td][align=center][b]默认颜色[/b][/align][/td]<br/>
[td][/td]
[/tr]<br/>

[tr]<br/>
[td][align=center]skyblue[/align][/td]<br/>
[td][align=center][color=skyblue]skyblue 天蓝色[/color][/align][/td]<br/>
[td][b][align=center][color=skyblue]skyblue 天蓝色[/color][/align][/b][/td]<br/>
[td][/td]
[/tr]<br/>

[/table]"#;
        let r = do_parse_content(text).unwrap();
        println!("{:#?}", r);
    }

    #[test]
    fn test_verbatim_workaround() {
        let text = r#"
[*]文字网址超链接：[url=
[size=100%]
网址]
[/size]
文字[/url
[size=100%]
]
[/size]

[*]字体大小：
[size=100%]
[
[/size]
[size=100%]
size=百分比]
[/size]
文字[
[size=100%]
/size]
[/size]
"#;
        let r = do_parse_content(text).unwrap();
        println!("{:#?}", r);
    }

    #[test]
    fn test_genshin_mismatched_close_tag() {
        let text = r#"
        [table]<br/>[tr]<br/>[td20][b][align=center][color=red][size=130%]版务公告[/size][/color][/align][/b][/td]<br/>[td rowspan=2 colspan=3][size=0]原神Logo[/size][align=center][size=0]原神Logo[/size][img]./mon_202008/22/-10yuu8Q5-9lsxKeT8S2s-28.png[/img]<br/>[color=silver]将军长生不灭，幕府锁国之期亦无尽头。<br/>追求&#39;永恒&#39;之神，在世人眼中见到了怎样的永恒?[/color][/align][/td]<br/>[td20][align=center][color=tomato][b][size=130%]同人创作[/size][/b][/color][/align][/td][/tr]<br/>[tr]<br/>[td][align=center][url=/read.php?tid=28339827][color=red][b]本版版规[/b][/color][/url][url=/read.php?tid=28339799][color=red][b]版务公告&amp;疑问意见反馈[/b][/color][/url]<br/>[url=/read.php?tid=28318948][color=red][b]版面活动[/b][/color][/url][url=/read.php?tid=28340190][color=red][b]申精/补分/打捞[/b][/color][/url]<br/>[url=/read.php?tid=24523685][color=red][b]发帖指南[/b][/color][/url][url=/read.php?tid=28339854][color=red][b]徽章兑换[/b][/color][/url][url=/read.php?tid=23326940][color=red][b]手机版版头[/b][/color][/url]<br/>[url=/read.php?tid=28339752][color=red]晒欧[/color][/url] [url=/read.php?tid=23345797][color=red]沉船[/color][/url] [url=/read.php?tid=27214494][color=red]水楼[/color][/url][/align][/td]<br/>[td][align=center][url=/read.php?tid=23849966][color=tomato][b]万文集舍藏书楼[/b][/color][/url][url=/read.php?tid=25749503][color=tomato][b]万文集舍图楼汇总索引[/b][/color][/url]<br/>[url=/read.php?tid=23604117][color=tomato][b]考据与同人创作汇总[/b][/color][/url][url=/read.php?tid=24924337][color=tomato][b]安科贴合集整理[/b][/color][/url]<br/>[url=/read.php?tid=25157962][color=tomato]人像拍摄的心得和技巧[/color][/url][url=/read.php?tid=24827770][color=tomato]龙脊雪山观光摄影[/color][/url][/align][/td][/tr]<br/>[tr]<br/>[td][align=center][color=blue][b][size=130%]数值计算[/size][/b][/color][/align][/td]<br/>[td rowspan=2 colspan=3][size=0%]版图 + 轮播角色图[/size][align=center][size=0%]版图 + 轮播角色图[/size][randomblock][url=/read.php?tid=28281857][img]./mon_202109/21/-10yuu8Qj7t-6vtlK1sT3cSj6-8w.jpg.medium.jpg[/img][/url][/randomblock]<br/>[randomblock][url=/read.php?tid=28281857][img]./mon_202109/21/-10yuu8Qj7t-aijxK1lT3cSj6-8w.jpg.medium.jpg[/img][/url][/randomblock]<br/>[randomblock][url=/read.php?tid=28281857][img]./mon_202108/30/-10yuu8Q176-384kK1kT3cSj6-8w.jpg.medium.jpg[/img][/url][/randomblock]<br/>[/align][/td]<br/>[td][align=center][color=chocolate][b][size=130%]攻略心得[/size][/b][/color][/align][/td][/tr]<br/>[tr]<br/>[td][align=center][url=/read.php?tid=23435445][color=blue][b]伤害数值计算与机制汇总[/b][/color][/url][url=/read.php?tid=24362520][color=blue][b]原神工具汇总[/b][/color][/url]<br/>[url=/read.php?tid=25564438][color=blue][b]《伤害乘区论》[/b][/color][/url][url=/read.php?tid=26824486][color=blue][b]《韧性力学》[/b][/color][/url]<br/>[url=/read.php?tid=24400590][color=blue][b]《高等元素论》[/b][/color][/url][url=/read.php?tid=25681266][color=blue][b]《高等元素论(附录)》[/b][/color][/url]<br/>[url=/read.php?tid=26794498][color=blue]《元素附着论》[/color][/url][url=/read.php?tid=23836189][color=blue]全角色施加元素附着时间[/color][/url]<br/>[url=/read.php?tid=23850775][color=blue]《扩散反应手册》[/color][/url][url=/read.php?tid=26932608][color=blue]《元素能量学》[/color][/url]<br/>[url=/read.php?tid=25127442][color=blue]《普通破盾学》[/color][/url][url=/read.php?tid=25537580][color=blue]《普通破盾学》续[/color][/url]<br/>[url=/read.php?tid=26432895][color=blue][b]圣遗物胚子评分[/b][/color][/url][url=/read.php?tid=25463257][color=blue]《圣遗物体力价值论》[/color][/url]<br/>[url=/read.php?tid=24270728][color=blue]《圣遗物数值学导论》[/color][/url][url=/read.php?tid=23576382][color=blue]圣遗物机制详解[/color][/url]<br/>[url=/read.php?tid=27431452][color=blue]原神人物技能倍率成长模型及分类[/color][/url][/align][/td]<br/>[td][align=center][url=/read.php?tid=24448426][color=chocolate][b]深境螺旋攻略合集[/b][/color][/url][url=/read.php?tid=26887673][color=chocolate][b]家园及钓鱼攻略合集[/b][/color][/url]<br/>[url=/read.php?tid=23367930][color=chocolate]风神瞳(蒙德)位置[/color][/url][url=/read.php?tid=23368056][color=chocolate]岩神瞳(璃月)位置[/color][/url]<br/>[url=/read.php?tid=24785827][color=chocolate]绯红玉髓(雪山)位置[/color][/url][url=/read.php?tid=27699709][color=chocolate]雷神瞳(稻妻)位置[/color][/url]<br/><br/>[url=/read.php?tid=23603640][color=chocolate][b]原神角色评测汇总[/b][/color][/url]<br/>[url=/read.php?tid=27703615][color=chocolate]神里绫华[/color][/url][url=/read.php?tid=27418170][color=chocolate]枫原万叶[/color][/url][url=/read.php?tid=26833730][color=chocolate]优菈[/color][/url]<br/>[url=/read.php?tid=26478064][color=chocolate]公子双火[/color][/url][url=/read.php?tid=25634102][color=chocolate]北斗双雷[/color][/url][url=/read.php?tid=28355228][color=chocolate]雷电将军[/color][/url]<br/>[url=/read.php?tid=25783438][color=chocolate]胡桃[/color][/url][url=/read.php?tid=26055894][color=chocolate]凯亚[/color][/url][url=/read.php?tid=24846473][color=chocolate]阿贝多[/color][/url][url=/read.php?tid=26380918][color=chocolate]辛焱[/color][/url]<br/>[url=/read.php?tid=27035535][color=chocolate]可莉[/color][/url][url=/read.php?tid=25411130][color=chocolate]魈[/color][/url][url=/read.php?tid=23591717][color=chocolate]雷泽[/color][/url][/align][/td][/tr]<br/>[tr]<br/>[td][align=center][b][color=purple][size=120%]冒险团笔记[/size][/color][/b][/align][/td]<br/>[td 20][align=center][b][color=green][size=120%]萌新攻略[/size][/color][/b][/align][/td]<br/>[td 20][align=center][b][color=darkblue][size=120%]日常推荐[/size][/color][/b][/align][/td]<br/>[td 20][align=center][b][color=royalblue][size=120%]猫尾酒馆[/size][/color][/b][/align][/td]<br/>[td][align=center][b][color=teal][size=120%]提瓦特大使馆[/size][/color][/b][/align][/td][/tr]<br/>[tr]<br/>[td][align=center][url=/read.php?tid=25843014][color=purple][b]全角色收益曲线、圣遗物推荐、参考面板[/b][/color][/url]<br/>[url=/read.php?tid=24079044][color=purple]抗性表及系数公式，详解各种增伤机制[/color][/url]<br/>[url=/read.php?tid=23642993&amp;amp;_ff=650][color=purple]每日挖矿路线推荐[/color][/url][url=/read.php?tid=23802190][color=purple]圣遗物评分体系[/color][/url]<br/>[url=/read.php?tid=23954929][color=purple]特殊副本&amp;支线任务攻略合集[/color][/url]<br/>[url=/read.php?tid=23882825][color=purple]书籍收集方式大全[/color][/url][url=/read.php?tid=23443257][color=purple]地图商人货物汇总[/color][/url][/align][/td]<br/>[td][align=center][url=/read.php?tid=26987864][color=green][b]原神基础游戏内容攻略整理分类[/b][/color][/url]<br/>[url=/read.php?tid=27859119][b][color=green]全角色圣遗物及武器搭配简述[/color][/b][/url]<br/>[url=/read.php?tid=25501812][color=green]泥潭交流手册[/color][/url][url=/read.php?tid=23359469][color=green]好友招募楼[/color][/url]<br/>[url=/read.php?tid=25870592][color=green]常规配队思路与位置思考[/color][/url]<br/>[url=/read.php?tid=28026734][color=green]原神抽卡概率工具表(仅供参考)[/color][/url][/align][/td]<br/>[td][align=center][url=/read.php?tid=27875210][color=darkblue][b]2.1圣遗物狗粮效率采集[/b][/color][/url]<br/>[url=/read.php?tid=28073645][color=darkblue][b]2.0版本精锻矿石刷新机制[/b][/color][/url]<br/>[url=/read.php?tid=23416874][color=darkblue]蒙德璃月刷怪路线[/color][/url][url=/read.php?tid=23464645][color=darkblue]挖矿机制及路线推荐[/color][/url]<br/>[url=/read.php?tid=24192272][color=darkblue]武器/人物突破 素材周常表[/color][/url]<br/>[url=/read.php?tid=23885052][color=darkblue]全特产采集[/color][/url][url=/read.php?tid=25273468][color=darkblue]懒人材料收集指南[/color][/url][/align][/td]<br/>[td][align=center][url=/read.php?tid=27730366][color=royalblue][b]2.0版本攻略汇总[/b][/color][/url][url=/read.php?tid=28472375][color=royalblue][b]2.1新版本攻略汇总[/b][/color][/url]<br/>[url=/read.php?tid=28391158][color=royalblue][b]原神2.1版本完美白嫖[/b][/color][/url]<br/>[url=/read.php?tid=28321485][color=royalblue][b]五精鱼叉快速获取攻略[/b][/color][/url]<br/>[url=/read.php?tid=28315777][color=royalblue][b]天云草实路线(目前180个)[/b][/color][/url]<br/>[url=/read.php?tid=27716986][color=royalblue]野伏众(刀镡)路线[/color][/url][url=/read.php?tid=27703526][color=royalblue]绯樱绣球路线[/color][/url]<br/>[/align][/td]<br/>[td][align=center][url=https://genshin.pub/][color=teal][b]今日素材本[/b][/color][/url][url=/read.php?tid=27152962][color=teal][b]Maid每日事项工具[/b][/color][/url]<br/>[url=https://weibo.com/u/7502751416][color=teal][b]NGA原神版微博[/b][/color][/url]<br/>[url=https://bbs.mihoyo.com/ys/obc/?bbs_presentation_style=no_header][color=teal][b]原神观测枢wiki[/b][/color][/url][url=https://wiki.biligame.com/ys/?curid=252][color=teal][b]原神地图工具[/b][/color][/url]<br/>[url=/read.php?tid=22869555][color=teal][b]攻略组招募丨加入冒险团[/b][/color][/url][/align][/td][/tr]<br/>[/table]<br/>[align=center][color=silver]Olah! 亲爱的旅行者们: 发帖请阅读[url=/read.php?tid=27917162][b]本版版规[/b][/url]，善用版头、精华区以及搜索功能; 发帖时请选择正确的版块，[b]错版会被锁隐并可能导致处罚[/b]。更多说明请看[url=/read.php?tid=24523685][b]发帖指南[/b][/url]。请勿讨论/宣传初始号，[b]严禁任何RMT(现金交易)行为[/b] [/align]<br/>[align=center]新交流一群518490267；交流二群684070156；新交流三群965556146；挖矿一群1156668308；挖矿二群912599725；挖矿3群: 546256232(已满) 审核反馈群：850950799(禁止聊天，仅用于加精过审申请)[/color][/align]
"#;
        let r = do_parse_content(text).unwrap();
        println!("{:#?}", r);
    }

    #[test]
    fn test_too_many_divider() {
        let text = &"======".repeat(10000).to_string();
        let r = do_parse_content(text).unwrap();
        println!("{:#?}", r);
    }

    #[test]
    fn test_stripbr() {
        let text = r#"
[randomblock]
[stripbr]
[fixsize height 20.999999 width 110 150 background #ffffff #ffffff][stripbr]
[style height 100% width 100% left 0 top 0 dybg 110%;100%;50%;0%;0%;./mon_202110/31/-10yuu8Q9vk-68x7K12T3cS1ls-a0.png][stripbr]
[style height 100% width 100% left 0 top 0 dybg 110%;40%;40%;400%;0%;./mon_202110/31/-10yuu8Q9vk-55fgKkT3cS1ls-a0.png][stripbr]
[style height 100% width 100% left 0 top 0 dybg 110%;50%;0%;600%;0%;./mon_202110/31/-10yuu8Q9vk-hx6oKlT3cS1ls-a0.png][stripbr]
[style height 100% width 100% left 0 top 0 dybg 110%;60%;0%;500%;0%;./mon_202110/31/-10yuu8Q17b-37huKiT3cS1ls-a0.png][stripbr]
[style height 100% width 100% left 0 top 0 dybg 120%;80%;10%;40%;30%;./mon_202110/31/-10yuu8Q9vk-jiehKvT3cS1ls-a0.png][stripbr]
[style height 100% width 100% left 0 top 0 dybg 130%;10%;0%;65%;30%;./mon_202110/31/-10yuu8Q9vk-ci8mKkT3cS1ls-a0.png][stripbr]
[style height 100% width 100% left 0 top 0 dybg 150%;10%;0%;45%;0%;./mon_202110/31/-10yuu8Q17b-3lylZgT3cS1ls-a0.png][stripbr]
[style height 100% width 100% left 0 top 0 dybg 150%;100%;0%;20%;0%;./mon_202110/31/-10yuu8Q9vk-42pwZdT3cS1ls-a0.png][stripbr]
[style height 100% width 100% left 0 top 0 dybg 115%;100%;50%;0%;0%;./mon_202110/31/-10yuu8Q17b-gjalKbT3cS1ls-a0.png][stripbr]
[style left 0 top 0 margin 0 0 0][stripbr][align=right][url=https://space.bilibili.com/730732][img]./mon_202111/05/-1165qiQmh6v-gvebK5T3cSz6-a0.png[/img][/url][/align]
[style left 0 top 0 margin 0 0 0][stripbr][align=left][url=https://space.bilibili.com/269415357][img]./mon_202111/05/-1165qiQr9f4-h4kbK4T1kShh-a0.png[/img][/url][/align]


[/style][stripbr]
[/style][stripbr]
[/style][stripbr]
[/style][stripbr]
[/style][stripbr]
[/style][stripbr]
[/style][stripbr]
[/style][stripbr]
[/style][stripbr]
[/style][stripbr]
[/style][stripbr]

[/randomblock]
        "#;

        let r = do_parse_content(text).unwrap();
        println!("{:#?}", r);
    }
}
