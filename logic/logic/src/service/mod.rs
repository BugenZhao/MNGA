use crate::{
    error::LogicResult,
    service::{constants::URL_BASE, utils::extract_error},
};
use lazy_static::lazy_static;
use reqwest::{Client, Url};

mod constants;
pub mod forum;
pub mod history;
mod macros;
pub mod post;
pub mod topic;
pub mod user;
mod utils;

#[cfg(test)]
#[path = "auth_debug.rs"]
pub mod auth;
#[cfg(not(test))]
pub mod auth;

fn build_client() -> Client {
    log::info!("build reqwest client");
    Client::builder().https_only(true).build().unwrap()
}

lazy_static! {
    static ref CLIENT: Client = build_client();
}

async fn fetch_package(
    api: &str,
    mut query: Vec<(&str, &str)>,
    mut form: Vec<(&str, &str)>,
) -> LogicResult<sxd_document::Package> {
    let url = Url::parse(&format!("{}/{}", URL_BASE, api)).unwrap();

    let auth_info = auth::AUTH_INFO.lock().unwrap().clone();
    let form = {
        form.push(("access_token", auth_info.get_token()));
        form.push(("access_uid", auth_info.get_uid()));
        form
    };

    let query = {
        query.push(("lite", "xml"));
        query.push(("__inchst", "UTF8"));
        query
    };

    // `tokio::test` make a new runtime for every test,
    // so we should use a thread-local client built in current runtime instead of a `lazy_static` one,
    // which may cause client being dropped early and `hyper` panicking at 'dispatch dropped without returning error'
    #[cfg(test)]
    let client = build_client();
    #[cfg(not(test))]
    let client = &CLIENT;

    let response = client
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
    let _ = extract_error(&package)?;
    Ok(package)
}
