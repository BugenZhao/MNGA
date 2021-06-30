use lazy_static::lazy_static;
use reqwest::{Client, Url};

use crate::{
    auth::{TOKEN, UID},
    error::LogicResult,
};

mod constants;
pub mod content;
pub mod forum;
mod macros;
pub mod topic;
pub mod user;
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
    mut form: Vec<(&str, &str)>,
) -> LogicResult<sxd_document::Package> {
    const URL_BASE: &str = "https://ngabbs.com";

    let url = Url::parse(&format!("{}/{}", URL_BASE, api)).unwrap();
    let form = {
        form.push(("access_token", TOKEN));
        form.push(("access_uid", UID));
        form
    };
    let query = {
        query.push(("lite", "xml"));
        query
    };

    let response = CLIENT
        .post(url)
        .form(&form)
        .query(&query)
        .send()
        .await?
        .text_with_charset("gb18030")
        .await?;

    #[cfg(test)]
    println!("{:?}", response);

    let package = sxd_document::parser::parse(&response)?;
    Ok(package)
}
