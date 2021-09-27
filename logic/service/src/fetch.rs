use std::time::Duration;

use crate::{
    auth,
    constants::{ANDROID_UA, APPLE_UA, DESKTOP_UA, URL_BASE},
    error::ServiceResult,
    utils::extract_error,
};
use lazy_static::lazy_static;
use protos::DataModel::Device;
use reqwest::{multipart, Client, RequestBuilder, Url};

fn device_ua() -> &'static str {
    match auth::AUTH_INFO.read().unwrap().get_device() {
        Device::DESKTOP => DESKTOP_UA,
        Device::APPLE => APPLE_UA,
        Device::ANDROID => ANDROID_UA,
    }
}

fn build_client() -> Client {
    log::info!("build reqwest client");
    Client::builder()
        .https_only(true)
        .timeout(Duration::from_secs(10))
        .build()
        .expect("failed to build reqwest client")
}

lazy_static! {
    static ref CLIENT: Client = build_client();
}

async fn do_fetch_package(
    api: &str,
    mut query: Vec<(&str, &str)>,
    add_form: impl FnOnce(RequestBuilder) -> RequestBuilder,
) -> ServiceResult<sxd_document::Package> {
    let url = Url::parse(api)
        .or_else(|_| Url::parse(&format!("{}/{}", URL_BASE, api)))
        .unwrap(); // todo: do not unwrap

    let query = {
        query.push(("lite", "xml"));
        query.push(("__inchst", "UTF8"));
        query
            .into_iter()
            .filter(|(_k, v)| !v.is_empty())
            .collect::<Vec<_>>()
    };

    // `tokio::test` make a new runtime for every test,
    // so we should use a thread-local client built in current runtime instead of a `lazy_static` one,
    // which may cause client being dropped early and `hyper` panicking at 'dispatch dropped without returning error'
    #[cfg(test)]
    let client = build_client();
    #[cfg(not(test))]
    let client = &CLIENT;

    let builder = client
        .post(url)
        .query(&query)
        .header("X-User-Agent", device_ua());
    let builder = add_form(builder);
    let response = builder.send().await?.text_with_charset("gb18030").await?;

    #[cfg(test)]
    println!("response: {:?}", response);

    let package = sxd_document::parser::parse(&response)?;
    let _ = extract_error(&package)?;
    Ok(package)
}

pub async fn fetch_package(
    api: &str,
    query: Vec<(&str, &str)>,
    mut form: Vec<(&str, &str)>,
) -> ServiceResult<sxd_document::Package> {
    let auth_info = auth::AUTH_INFO.read().unwrap().clone();
    let form = {
        form.push(("access_token", auth_info.get_token()));
        form.push(("access_uid", auth_info.get_uid()));
        form
    };

    do_fetch_package(api, query, |b| b.form(&form)).await
}

pub async fn fetch_package_multipart(
    api: &str,
    query: Vec<(&str, &str)>,
    form: multipart::Form,
) -> ServiceResult<sxd_document::Package> {
    let auth_info = auth::AUTH_INFO.read().unwrap().clone();
    let form = form
        .percent_encode_path_segment()
        .text("access_token", auth_info.token) // todo: really needed ?
        .text("access_uid", auth_info.uid);

    do_fetch_package(api, query, |b| b.multipart(form)).await
}
