use crate::{
    constants::SUCCESS_MSGS,
    error::{ServiceError, ServiceResult},
};
use chrono::{DateTime, FixedOffset, Utc};
use protos::DataModel::ErrorMessage;
use serde_json::Value;
use std::{borrow::Cow, collections::HashMap};
use sxd_document::Package;
use sxd_xpath::{Context, Factory, XPath, nodeset::Node};
use uuid::Uuid;

fn to_xpath(s: &str) -> ServiceResult<XPath> {
    let factory = Factory::new();
    let xpath = factory.build(s).ok().flatten();
    xpath.ok_or_else(|| sxd_xpath::Error::NoXPath.into())
}

pub fn extract_kv(node: Node<'_>) -> HashMap<&str, String> {
    node.children()
        .into_iter()
        .filter(|n| matches!(n, Node::Element(_)))
        .map(|n| (n.expanded_name().unwrap().local_part(), n.string_value()))
        .collect::<HashMap<_, _>>()
}

/// Collects the element children of `node` as `(tag, text)` pairs. Text children, such as the
/// `3` in `<error>3</error>`, have no name and are skipped.
pub fn extract_kv_pairs(node: Node<'_>) -> Vec<(&str, String)> {
    node.children()
        .into_iter()
        .filter(|n| matches!(n, Node::Element(_)))
        .filter_map(|n| Some((n.expanded_name()?.local_part(), n.string_value())))
        .collect::<Vec<_>>()
}

pub fn json_value_to_string(value: &Value) -> Option<String> {
    match value {
        Value::Null => Some(String::new()),
        Value::String(s) => Some(s.clone()),
        Value::Number(n) => Some(n.to_string()),
        Value::Bool(b) => Some(if *b { "1".to_owned() } else { "0".to_owned() }),
        _ => None,
    }
}

pub fn json_field<'a>(value: &'a Value, key: &str) -> Option<&'a Value> {
    value.as_object()?.get(key)
}

pub fn json_object_values(value: &Value) -> impl Iterator<Item = &Value> + '_ {
    value
        .as_object()
        .into_iter()
        .flat_map(|object| object.values())
}

pub fn json_string(value: &Value, key: &str) -> Option<String> {
    json_field(value, key).and_then(json_value_to_string)
}

pub fn json_u32(value: &Value, key: &str) -> Option<u32> {
    json_field(value, key).and_then(|v| {
        v.as_u64()
            .and_then(|n| u32::try_from(n).ok())
            .or_else(|| v.as_str().and_then(|s| s.parse::<u32>().ok()))
    })
}

pub fn json_u64(value: &Value, key: &str) -> Option<u64> {
    json_field(value, key).and_then(|v| {
        v.as_u64()
            .or_else(|| v.as_str().and_then(|s| s.parse::<u64>().ok()))
    })
}

pub fn json_i64(value: &Value, key: &str) -> Option<i64> {
    json_field(value, key).and_then(|v| {
        v.as_i64()
            .or_else(|| v.as_u64().and_then(|n| i64::try_from(n).ok()))
            .or_else(|| v.as_str().and_then(|s| s.parse::<i64>().ok()))
    })
}

pub fn json_bool(value: &Value, key: &str) -> Option<bool> {
    json_field(value, key).and_then(|v| {
        v.as_bool().or_else(|| {
            v.as_u64().map(|n| n != 0).or_else(|| {
                v.as_i64()
                    .map(|n| n != 0)
                    .or_else(|| v.as_str().map(|s| !s.is_empty() && s != "0"))
            })
        })
    })
}

pub fn sanitize_json_control_chars_in_strings(response: &str) -> Cow<'_, str> {
    let mut escaped = false;
    let mut in_string = false;
    let mut sanitized = String::with_capacity(response.len());
    let mut changed = false;

    for c in response.chars() {
        if !in_string {
            if c == '"' {
                in_string = true;
            }
            sanitized.push(c);
            continue;
        }

        if escaped {
            escaped = false;
            sanitized.push(c);
            continue;
        }

        match c {
            '\\' => {
                escaped = true;
                sanitized.push(c);
            }
            '"' => {
                in_string = false;
                sanitized.push(c);
            }
            '\u{08}' => {
                changed = true;
                sanitized.push_str("\\b");
            }
            '\t' => {
                changed = true;
                sanitized.push_str("\\t");
            }
            '\n' => {
                changed = true;
                sanitized.push_str("\\n");
            }
            '\u{0C}' => {
                changed = true;
                sanitized.push_str("\\f");
            }
            '\r' => {
                changed = true;
                sanitized.push_str("\\r");
            }
            '\u{0000}'..='\u{001F}' => {
                changed = true;
                let escaped = format!("\\u{:04x}", c as u32);
                sanitized.push_str(&escaped);
            }
            _ => sanitized.push(c),
        }
    }

    if changed {
        Cow::Owned(sanitized)
    } else {
        Cow::Borrowed(response)
    }
}

pub fn extract_nodes<T, F>(package: &Package, xpath: &str, f: F) -> ServiceResult<Vec<T>>
where
    F: Fn(Vec<Node>) -> Vec<T>,
{
    let document = package.as_document();
    extract_nodes_rel(document.root().into(), xpath, f)
}

pub fn extract_nodes_rel<T, F>(node: Node, xpath: &str, f: F) -> ServiceResult<Vec<T>>
where
    F: Fn(Vec<Node>) -> Vec<T>,
{
    let xpath = to_xpath(xpath)?;
    let context = Context::new();

    let items = xpath
        .evaluate(&context, node)
        .map_err(sxd_xpath::Error::Executing)?;
    let extracted = if let sxd_xpath::Value::Nodeset(nodeset) = items {
        f(nodeset.document_order())
    } else {
        vec![]
    };

    Ok(extracted)
}

pub fn extract_node<T, F>(package: &Package, xpath: &str, f: F) -> ServiceResult<Option<T>>
where
    F: Fn(Node) -> T,
{
    let document = package.as_document();
    extract_node_rel(document.root().into(), xpath, f)
}

pub fn extract_node_rel<T, F>(node: Node, xpath: &str, f: F) -> ServiceResult<Option<T>>
where
    F: Fn(Node) -> T,
{
    let xpath = to_xpath(xpath)?;
    let context = Context::new();

    let item = xpath
        .evaluate(&context, node)
        .map_err(sxd_xpath::Error::Executing)?;
    let extracted = if let sxd_xpath::Value::Nodeset(nodeset) = item {
        nodeset.into_iter().next().map(f)
    } else {
        None
    };

    Ok(extracted)
}

pub fn extract_string(package: &Package, xpath: &str) -> ServiceResult<String> {
    let document = package.as_document();
    let item = sxd_xpath::evaluate_xpath(&document, xpath)?;
    Ok(item.into_string())
}

pub fn extract_string_rel(node: Node, xpath: &str) -> ServiceResult<String> {
    let xpath = to_xpath(xpath)?;
    let context = Context::new();

    let item = xpath
        .evaluate(&context, node)
        .map_err(sxd_xpath::Error::Executing)?;
    Ok(item.into_string())
}

pub fn extract_pages(
    package: &Package,
    rows_xpath: &str,
    rows_per_page_xpath: &str,
    default_per_page: u32,
) -> ServiceResult<u32> {
    let rows = extract_string(package, rows_xpath)?
        .parse::<u32>()
        .ok()
        .unwrap_or(1);

    let rows_per_page = extract_string(package, rows_per_page_xpath)?
        .parse::<u32>()
        .ok()
        .unwrap_or(default_per_page);

    let pages = rows / rows_per_page + u32::from(rows % rows_per_page != 0);

    Ok(pages)
}

pub fn extract_error(package: &Package) -> ServiceResult<()> {
    use super::macros::pget;

    let frontend = extract_node(package, "/root/__MESSAGE", |n| {
        let pairs = extract_kv_pairs(n);
        let code = pget!(pairs, 0).unwrap_or_default();
        let info = pget!(pairs, 1).unwrap_or_default();

        ErrorMessage {
            code,
            info,
            ..Default::default()
        }
    })?;

    let error_code = extract_string(package, "/root/error_code")?;

    let backend = extract_node(package, "/root/error", |n| {
        let pairs = extract_kv_pairs(n);
        // Usually `<error><item>message</item></error>`, but the attachment server replies with a
        // bare code like `<error>3</error>`.
        let info = pget!(pairs, 0).or_else(|| {
            let text = n.string_value();
            (!text.trim().is_empty()).then(|| text.trim().to_owned())
        });

        info.map(|info| ErrorMessage {
            code: error_code.clone(),
            info,
            ..Default::default()
        })
    })?
    .flatten();

    let backend_code = (!error_code.is_empty()).then(|| ErrorMessage {
        code: error_code.clone(),
        ..Default::default()
    });

    frontend.or(backend).or(backend_code).map_or_else(
        || Ok(()),
        |mut e| {
            if e.get_code().is_empty() {
                e.set_code("?".to_owned());
            }
            if SUCCESS_MSGS.iter().any(|msg| e.info.contains(msg)) {
                Ok(())
            } else {
                Err(ServiceError::Nga(e))
            }
        },
    )
}

#[inline]
pub fn get_unique_id() -> String {
    Uuid::new_v4().to_string()
}

#[inline]
pub fn server_now() -> DateTime<FixedOffset> {
    const HOUR: i32 = 3600;
    Utc::now().with_timezone(&FixedOffset::east_opt(8 * HOUR).unwrap())
}

#[inline]
pub fn server_today_string() -> String {
    server_now().format("%Y-%m-%d").to_string()
}

#[cfg(test)]
mod test {
    use super::*;

    #[test]
    fn test_sanitize_control_chars_in_json_strings() {
        let input = "{\"data\":{\"message\":\"a\tb\nc\r\nd\",\"escaped\":\"x\\\\ty\",\"n\":1}}";
        let sanitized = sanitize_json_control_chars_in_strings(input);

        assert_eq!(
            sanitized,
            "{\"data\":{\"message\":\"a\\tb\\nc\\r\\nd\",\"escaped\":\"x\\\\ty\",\"n\":1}}"
        );
    }

    fn parse_error(xml: &str) -> ServiceResult<()> {
        extract_error(&sxd_document::parser::parse(xml).unwrap())
    }

    #[test]
    fn test_extract_error_with_bare_code() {
        // Returned by the attachment server, for example when `auth` has expired.
        let err = parse_error(
            r#"<?xml version="1.0" encoding="GBK"?><root><error>3</error><error_code>3</error_code></root>"#,
        )
        .unwrap_err();

        match err {
            ServiceError::Nga(e) => {
                assert_eq!(e.code, "3");
                assert_eq!(e.info, "3");
            }
            other => panic!("unexpected error: {other:?}"),
        }
    }

    #[test]
    fn test_extract_error_with_items() {
        let err =
            parse_error("<root><error><item>message</item><item>detail</item></error></root>")
                .unwrap_err();

        match err {
            ServiceError::Nga(e) => {
                assert_eq!(e.code, "?");
                assert_eq!(e.info, "message");
            }
            other => panic!("unexpected error: {other:?}"),
        }
    }

    #[test]
    fn test_extract_error_frontend_message() {
        let err = parse_error(
            "<root><__MESSAGE><item>17</item><item>message</item><item>detail</item></__MESSAGE></root>",
        )
        .unwrap_err();

        match err {
            ServiceError::Nga(e) => {
                assert_eq!(e.code, "17");
                assert_eq!(e.info, "message");
            }
            other => panic!("unexpected error: {other:?}"),
        }
    }

    #[test]
    fn test_extract_error_none() {
        parse_error("<root><attachments>a</attachments><url>u</url></root>").unwrap();
    }

    #[test]
    fn test_extract_kv_pairs_skips_text() {
        let package =
            sxd_document::parser::parse("<root><e>text<i>a</i>more<i>b</i></e></root>").unwrap();
        let pairs = extract_node(&package, "/root/e", |n| {
            extract_kv_pairs(n)
                .into_iter()
                .map(|(k, v)| (k.to_owned(), v))
                .collect::<Vec<_>>()
        })
        .unwrap()
        .unwrap();

        assert_eq!(
            pairs,
            vec![
                ("i".to_owned(), "a".to_owned()),
                ("i".to_owned(), "b".to_owned())
            ]
        );
    }
}
