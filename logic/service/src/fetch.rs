#![allow(clippy::declare_interior_mutable_const)]

use std::{borrow::Cow, sync::Mutex, time::Duration};

use crate::{
    auth,
    constants::{
        ANDROID_UA, APPLE_UA, DEFAULT_MOCK_BASE_URL, DEFAULT_PROXY_BASE_URL, DESKTOP_UA,
        WINDOWS_PHONE_UA,
    },
    error::{ServiceError, ServiceResult},
    request,
    utils::extract_error,
};
use itertools::Itertools;
use lazy_static::lazy_static;
use protos::DataModel::Device;
use rand::{Rng, seq::SliceRandom as _};
use reqwest::{Client, Method, RequestBuilder, Response, Url, multipart};

fn device_ua(api: &str) -> Cow<'static, str> {
    let option = request::REQUEST_OPTION.read().unwrap();

    // If not customized, always use windows phone for read.php since it seems to be more robust.
    if api == "read.php" && option.get_device() != Device::CUSTOM {
        return WINDOWS_PHONE_UA.into();
    }

    match option.get_device() {
        Device::DESKTOP => DESKTOP_UA,
        Device::APPLE => APPLE_UA,
        Device::ANDROID => ANDROID_UA,
        Device::WINDOWS_PHONE => WINDOWS_PHONE_UA,
        // Use `custom_ua` if `device` is `CUSTOM`
        Device::CUSTOM => return option.get_custom_ua().to_owned().into(),
    }
    .into()
}

fn resolve_url(api: &str, kind: FetchKind) -> ServiceResult<Url> {
    let url = Url::parse(api) // if absolute
        .or_else(|_| -> ServiceResult<Url> {
            let option = request::REQUEST_OPTION.read().unwrap();
            let base = match kind {
                FetchKind::Normal => option.get_base_url_v2(),
                FetchKind::Mock => DEFAULT_MOCK_BASE_URL,
                FetchKind::Proxy => DEFAULT_PROXY_BASE_URL,
            };
            // Make sure there's a trailing slahs in `base`!
            let url = Url::parse(base)?.join(api)?;
            Ok(url)
        })?;

    Ok(url)
}

fn build_client() -> Client {
    log::info!("build reqwest client");
    Client::builder()
        .https_only(true)
        .timeout(Duration::from_secs(10))
        .gzip(true)
        .build()
        .expect("failed to build reqwest client")
}

static CLIENT: Mutex<Option<Client>> = Mutex::new(None);

// Take the global client. It will be recreated on next fetch.
fn invalidate_global_client() {
    let _ = CLIENT.lock().unwrap().take();
}

fn get_global_client() -> Client {
    CLIENT
        .lock()
        .unwrap()
        .get_or_insert_with(build_client)
        .clone()
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

/// Determine the base URL of the request.
#[derive(Copy, Clone, Debug)]
enum FetchKind {
    Normal,
    Mock,
    Proxy,
}

async fn do_fetch<AF>(
    api: &str,
    kind: FetchKind,
    mut query: Vec<(&str, &str)>,
    method: Method,
    // NGA may return detailed error message in the response body when the status code is not OK.
    // So we should not directly return a `ServiceError::Status`.
    check_status: bool,
    add_form: AF,
) -> ServiceResult<Response>
where
    AF: FnOnce(RequestBuilder) -> RequestBuilder,
{
    let url = resolve_url(api, kind)?;

    let query = {
        query.push(("__inchst", "UTF8"));
        query
            .into_iter()
            .filter(|(_k, v)| !v.is_empty())
            .collect::<Vec<_>>()
    };

    // `tokio::test` make a new runtime for every test,
    // so we should use a thread-local client built in current runtime instead of a global one,
    // which may cause client being dropped early and `hyper` panicking at 'dispatch dropped without returning error'
    let client = if cfg!(test) {
        build_client()
    } else {
        get_global_client()
    };

    let ua = &*device_ua(api);
    let builder = client
        .request(method, url)
        .query(&query)
        .header("User-Agent", ua)
        .header("X-User-Agent", ua);
    let builder = add_form(builder);

    let request = builder.build()?;
    #[cfg(test)]
    println!("request to url: {}", request.url());
    log::info!("request to url: {}", request.url());

    let response = client.execute(request).await?;

    if response.status().is_success() {
        Ok(response)
    } else {
        log::error!(
            "request failed: {}",
            response.error_for_status_ref().unwrap_err()
        );
        if check_status {
            Err(ServiceError::from_status(response.status()))
        } else {
            Ok(response)
        }
    }
}

trait ResponseFormat: Sized {
    fn query_pairs() -> &'static [(&'static str, &'static str)];
    fn parse_response(response: String) -> ServiceResult<Self>;
}

async fn do_fetch_text<RF, AF>(
    api: &str,
    query: Vec<(&str, &str)>,
    add_form: AF,
) -> ServiceResult<RF>
where
    RF: ResponseFormat,
    AF: Fn(RequestBuilder) -> RequestBuilder,
{
    let mut attempts = [FetchKind::Normal, FetchKind::Proxy]
        .into_iter()
        .cartesian_product(RF::query_pairs())
        .collect_vec();
    // Shuffle attempts except for the primary one.
    attempts[1..].shuffle(&mut rand::rng());

    let mut first_error = None;

    // Try different query pairs to mitigate blocking.
    for (kind, query_pair) in attempts {
        let mut query = query.clone();
        query.push(*query_pair);

        // Sleep for a random duration.
        let duration = Duration::from_millis(rand::rng().random_range(100..=300));
        tokio::time::sleep(duration).await;

        let result = async {
            let response = do_fetch(api, kind, query, Method::POST, false, &add_form).await?;
            let status = response.status();
            let response = response.text_with_charset("gb18030").await?;

            #[cfg(test)]
            let _ = RESPONSE_CB.try_with(|c| c.borrow_mut()(&response));
            #[cfg(test)]
            println!("http response: {}", response);

            if response.is_empty() && !status.is_success() {
                // Parse must fail. Here we use the error message from the status code.
                return Err(ServiceError::from_status(status));
            }
            RF::parse_response(response)
        }
        .await;

        match result {
            Ok(r) => {
                if first_error.is_some() {
                    log::info!(
                        "successfully parsed with `{}={}`",
                        query_pair.0,
                        query_pair.1
                    );
                }
                return Ok(r);
            }
            // We may get `Status` error when being rate limited or via proxy.
            Err(error)
                if error.is_response_parse_error() || matches!(error, ServiceError::Status(_)) =>
            {
                log::error!(
                    "failed to parse response with `{}={}`, retrying: {}",
                    query_pair.0,
                    query_pair.1,
                    error
                );
                invalidate_global_client();
                if first_error.is_none() {
                    first_error = Some(error);
                }
            }
            Err(error) => {
                // For other errors, we don't need to retry.
                return Err(error);
            }
        }
    }

    log::error!("all query pairs failed, giving up");
    Err(first_error.unwrap())
}

#[inline]
async fn fetch_text_with_auth<RF>(
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

    do_fetch_text(api, query, |b| b.form(&form)).await
}

mod xml {
    use super::*;

    impl ResponseFormat for sxd_document::Package {
        fn query_pairs() -> &'static [(&'static str, &'static str)] {
            &[
                ("lite", "xml"),
                // compact XML
                ("__output", "10"),
                // exactly same as `lite=xml`, useless
                // ("__output", "9"),
                // need some effort to make JSON schema compatible with XML
                // ("__output", "11"), // verbose JSON
                // ("__output", "8"),  // compact JSON
            ]
        }

        fn parse_response(response: String) -> ServiceResult<Self> {
            // If it is a JSON, convert to XML first.
            // if response.starts_with("{") {
            //     // Fix control chars.
            //     let r = response
            //         .replace('\t', " ")
            //         .replace(|c: char| c.is_ascii_control(), "");
            //     let mut value: serde_json::Value = serde_json::from_str(&r)?;
            //     value = value["data"].take();

            //     let mut buffer = String::new();
            //     let ser = quick_xml::se::Serializer::with_root(&mut buffer, Some("root"))?;
            //     value.serialize(ser)?;
            //     response = buffer;
            // }

            let package = sxd_document::parser::parse(&response)?;
            extract_error(&package)?;
            Ok(package)
        }
    }

    pub async fn fetch_package(
        api: &str,
        query: Vec<(&str, &str)>,
        form: Vec<(&str, &str)>,
    ) -> ServiceResult<sxd_document::Package> {
        fetch_text_with_auth(api, query, form).await
    }

    pub async fn fetch_package_multipart(
        api: &str,
        query: Vec<(&str, &str)>,
        make_form: impl Fn() -> multipart::Form,
    ) -> ServiceResult<sxd_document::Package> {
        let auth_info = auth::AUTH_INFO.read().unwrap().clone();
        let make_form = move || {
            make_form()
                .percent_encode_path_segment()
                .text("access_token", auth_info.token.clone()) // todo: really needed ?
                .text("access_uid", auth_info.uid.clone())
        };

        do_fetch_text(api, query, |b| b.multipart(make_form())).await
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
        fn query_pairs() -> &'static [(&'static str, &'static str)] {
            &[("__output", "8")]
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
        fetch_text_with_auth(api, query, form).await
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

mod mock {
    use super::*;
    use protos::{MockRequest, MockResponse};

    pub async fn fetch_mock<Req, Res>(request: &Req) -> ServiceResult<Res>
    where
        Req: MockRequest,
        Res: MockResponse,
    {
        let api = request.to_encoded_mock_api()?;
        let response = do_fetch(&api, FetchKind::Mock, vec![], Method::GET, true, |b| b)
            .await?
            .bytes()
            .await?;

        let response = Res::parse_from_bytes(&response)?;
        Ok(response)
    }
}

pub use self::json::*;
pub use self::mock::*;
pub use self::xml::*;
