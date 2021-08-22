use protos::DataModel::Attachment;
use sxd_xpath::nodeset::Node;

use crate::utils::extract_kv;

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
