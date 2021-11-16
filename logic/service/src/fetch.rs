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

#[cfg(test)]
tokio::task_local! {
    static RESPONSE_CB: std::cell::RefCell<Box<dyn FnMut(&str)>>;
}

#[cfg(test)]
pub async fn with_fetch_check<F: futures::Future>(
    cb: impl FnMut(&str) + 'static,
    f: F,
) -> <F as futures::Future>::Output {
    RESPONSE_CB
        .scope(std::cell::RefCell::new(Box::new(cb)), f)
        .await
}

trait ResponseFormat: Sized {
    fn query_pair() -> (&'static str, &'static str);
    fn parse_response(response: String) -> ServiceResult<Self>;
}

async fn do_fetch<RF, AF>(
    api: &str,
    mut query: Vec<(&str, &str)>,
    add_form: AF,
) -> ServiceResult<RF>
where
    RF: ResponseFormat,
    AF: FnOnce(RequestBuilder) -> RequestBuilder,
{
    let url = Url::parse(api).or_else(|_| Url::parse(&format!("{}/{}", URL_BASE, api)))?;

    let query = {
        query.push(RF::query_pair());
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
    let _ = RESPONSE_CB.try_with(|c| c.borrow_mut()(&response));

    RF::parse_response(response)
}

#[inline]
async fn fetch_generic<RF>(
    api: &str,
    query: Vec<(&str, &str)>,
    mut form: Vec<(&str, &str)>,
) -> ServiceResult<RF>
where
    RF: ResponseFormat,
{
    let auth_info = auth::AUTH_INFO.read().unwrap().clone();
    let form = {
        form.push(("access_token", auth_info.get_token()));
        form.push(("access_uid", auth_info.get_uid()));
        form
    };

    do_fetch(api, query, |b| b.form(&form)).await
}

mod xml {
    use super::*;

    impl ResponseFormat for sxd_document::Package {
        fn query_pair() -> (&'static str, &'static str) {
            ("lite", "xml")
        }

        fn parse_response(response: String) -> ServiceResult<Self> {
            let package = sxd_document::parser::parse(&response)?;
            let _ = extract_error(&package)?;
            Ok(package)
        }
    }

    pub async fn fetch_package(
        api: &str,
        query: Vec<(&str, &str)>,
        form: Vec<(&str, &str)>,
    ) -> ServiceResult<sxd_document::Package> {
        fetch_generic(api, query, form).await
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

        do_fetch(api, query, |b| b.multipart(form)).await
    }
}

mod json {
    use super::*;
    use regex::Regex;

    lazy_static! {
        // HACK: int as object key
        static ref RE: Regex = Regex::new(r"([{,}]\s*)(\d+)(:)").unwrap();
    }

    impl ResponseFormat for serde_json::Value {
        fn query_pair() -> (&'static str, &'static str) {
            ("__output", "8")
        }

        fn parse_response(response: String) -> ServiceResult<Self> {
            let mut value = serde_json::from_str::<serde_json::Value>(&response).or_else(|_| {
                let fixed_response = RE.replace_all(&response, r#"$1"$2"$3"#);
                #[cfg(test)]
                println!("fixed json: {}", fixed_response);
                serde_json::from_str(&fixed_response)
            })?;
            let value = value["data"].take();
            Ok(value)
        }
    }

    pub async fn fetch_json_value(
        api: &str,
        query: Vec<(&str, &str)>,
        form: Vec<(&str, &str)>,
    ) -> ServiceResult<serde_json::Value> {
        fetch_generic(api, query, form).await
    }

    #[cfg(test)]
    mod test {
        use super::*;

        #[test]
        fn test_int_key() {
            let s = r#"{"data": { 1: "233", 2: "233" }}"#.to_owned();
            let v = serde_json::Value::parse_response(s).unwrap();
            println!("{:#?}", v);
        }
    }
}

pub use self::json::*;
pub use self::xml::*;
