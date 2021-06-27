use std::collections::HashMap;

use sxd_document::Package;
use sxd_xpath::nodeset::{Node, Nodeset};

use crate::error::LogicResult;

pub fn extract_kv(node: Node) -> HashMap<&str, String> {
    node.children()
        .into_iter()
        .map(|n| (n.expanded_name().unwrap().local_part(), n.string_value()))
        .collect::<HashMap<_, _>>()
}

pub fn extract_nodeset<T, F>(package: &Package, xpath: &str, f: F) -> LogicResult<Vec<T>>
where
    F: Fn(Nodeset) -> Vec<T>,
{
    let document = package.as_document();
    let items = sxd_xpath::evaluate_xpath(&document, xpath)?;
    let extracted = if let sxd_xpath::Value::Nodeset(nodeset) = items {
        f(nodeset)
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
    let item = sxd_xpath::evaluate_xpath(&document, xpath)?;
    let extracted = if let sxd_xpath::Value::Nodeset(nodeset) = item {
        nodeset.into_iter().next().map(|node| f(node))
    } else {
        None
    };
    Ok(extracted)
}
