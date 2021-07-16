use std::time::Duration;

use crate::{auth, constants::URL_BASE, error::ServiceResult, utils::extract_error};
use lazy_static::lazy_static;
use reqwest::{
    header::{HeaderMap, HeaderValue},
    Client, Url,
};

fn build_client() -> Client {
    log::info!("build reqwest client");
    let headers = {
        let mut headers = HeaderMap::new();
        headers.insert(
            "X-User-Agent",
            HeaderValue::from_static("NGA_skull/7.2.4(iPhone13,2;iOS 14.6)"),
        );
        headers
    };
    Client::builder()
        .https_only(true)
        .default_headers(headers)
        .timeout(Duration::from_secs(10))
        .build()
        .expect("failed to build reqwest client")
}

lazy_static! {
    static ref CLIENT: Client = build_client();
}

pub async fn fetch_package(
    api: &str,
    mut query: Vec<(&str, &str)>,
    mut form: Vec<(&str, &str)>,
) -> ServiceResult<sxd_document::Package> {
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
