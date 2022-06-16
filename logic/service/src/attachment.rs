use protos::DataModel::Attachment;
use sxd_xpath::nodeset::Node;

use crate::utils::extract_kv;
use serde_json::Value;

pub fn extract_attachment(node: Node) -> Option<Attachment> {
    use super::macros::get;
    let map = extract_kv(node);

    let attachment = Attachment {
        url: get!(map, "attachurl")?,
        size: get!(map, "size", _).unwrap_or_default(),
        field_type: get!(map, "type").unwrap_or_default(),
        ..Default::default()
    };

    Some(attachment)
}

pub fn extract_attachment_json(value: &Value) -> Option<Attachment> {
    let attachment = Attachment {
        url: value["attachurl"].as_str().unwrap_or_default().to_string(),
        size: value["size"].as_u64().unwrap_or_default(),
        field_type: value["type"].as_str().unwrap_or_default().to_string(),
        ..Default::default()
    };

    Some(attachment)
}
