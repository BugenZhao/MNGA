use std::collections::HashMap;

use sxd_document::Package;
use sxd_xpath::{nodeset::Node, Context, Factory, XPath};

use crate::error::LogicResult;

fn to_xpath(s: &str) -> LogicResult<XPath> {
    let factory = Factory::new();
    let xpath = factory.build(s).ok().flatten();
    xpath.ok_or(sxd_xpath::Error::NoXPath.into())
}

pub fn extract_kv(node: Node) -> HashMap<&str, String> {
    node.children()
        .into_iter()
        .filter(|n| matches!(n, Node::Element(_)))
        .map(|n| (n.expanded_name().unwrap().local_part(), n.string_value()))
        .collect::<HashMap<_, _>>()
}

pub fn extract_kv_pairs(node: Node) -> Vec<(&str, String)> {
    node.children()
        .into_iter()
        // fixme: filter element?
        .map(|n| (n.expanded_name().unwrap().local_part(), n.string_value()))
        .collect::<Vec<_>>()
}

pub fn extract_nodes<T, F>(package: &Package, xpath: &str, f: F) -> LogicResult<Vec<T>>
where
    F: Fn(Vec<Node>) -> Vec<T>,
{
    let document = package.as_document();
    extract_nodes_rel(document.root().into(), xpath, f)
}

pub fn extract_nodes_rel<T, F>(node: Node, xpath: &str, f: F) -> LogicResult<Vec<T>>
where
    F: Fn(Vec<Node>) -> Vec<T>,
{
    let xpath = to_xpath(xpath)?;
    let context = Context::new();

    let items = xpath
        .evaluate(&context, node)
        .map_err(|ee| sxd_xpath::Error::Executing(ee))?;
    let extracted = if let sxd_xpath::Value::Nodeset(nodeset) = items {
        f(nodeset.document_order())
    } else {
        vec![]
    };

    Ok(extracted)
}

pub fn extract_node<T, F>(package: &Package, xpath: &str, f: F) -> LogicResult<Option<T>>
where
    F: Fn(Node) -> T,
{
    let document = package.as_document();
    extract_node_rel(document.root().into(), xpath, f)
}

pub fn extract_node_rel<T, F>(node: Node, xpath: &str, f: F) -> LogicResult<Option<T>>
where
    F: Fn(Node) -> T,
{
    let xpath = to_xpath(xpath)?;
    let context = Context::new();

    let item = xpath
        .evaluate(&context, node)
        .map_err(|ee| sxd_xpath::Error::Executing(ee))?;
    let extracted = if let sxd_xpath::Value::Nodeset(nodeset) = item {
        nodeset.into_iter().next().map(|node| f(node))
    } else {
        None
    };

    Ok(extracted)
}

pub fn extract_string(package: &Package, xpath: &str) -> LogicResult<String> {
    let document = package.as_document();
    let item = sxd_xpath::evaluate_xpath(&document, xpath)?;
    Ok(item.into_string())
}

pub fn extract_pages(
    package: &Package,
    rows_xpath: &str,
    rows_per_page_xpath: &str,
    default_per_page: u32,
) -> LogicResult<u32> {
    let rows = extract_string(&package, rows_xpath)?
        .parse::<u32>()
        .ok()
        .unwrap_or(1);

    let rows_per_page = extract_string(&package, rows_per_page_xpath)?
        .parse::<u32>()
        .ok()
        .unwrap_or(default_per_page);

    let pages = rows / rows_per_page + u32::from(rows % rows_per_page != 0);

    Ok(pages)
}
