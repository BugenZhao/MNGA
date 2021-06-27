use lazy_static::lazy_static;
use reqwest::{Client, Url};

use crate::{
    config::{TOKEN, UID},
    error::LogicResult,
};

pub mod topic;
mod utils;

fn build_client() -> Client {
    Client::builder().https_only(true).build().unwrap()
}

lazy_static! {
    pub static ref CLIENT: Client = build_client();
}

async fn fetch_package(
    api: &str,
    mut query: Vec<(&str, &str)>,
) -> LogicResult<sxd_document::Package> {
    const URL_BASE: &str = "https://ngabbs.com";

    let url = Url::parse(&format!("{}/{}", URL_BASE, api)).unwrap();
    let params = [("access_token", TOKEN), ("access_uid", UID)];
    let query = {
        query.push(("lite", "xml"));
        query
    };

    let response = CLIENT
        .post(url)
        .form(&params)
        .query(&query)
        .send()
        .await?
        .text_with_charset("gb18030")
        .await?;

    let package = sxd_document::parser::parse(&response)?;
    Ok(package)
}
