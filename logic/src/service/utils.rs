use std::collections::HashMap;

use sxd_xpath::nodeset::Node;

pub fn extract_map(node: Node) -> HashMap<&str, String> {
    node.children()
        .into_iter()
        .map(|n| (n.expanded_name().unwrap().local_part(), n.string_value()))
        .collect::<HashMap<_, _>>()
}
