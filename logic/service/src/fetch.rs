#![allow(clippy::declare_interior_mutable_const)]

use std::{borrow::Cow, time::Duration};

use crate::{
    auth,
    constants::{ANDROID_UA, APPLE_UA, DEFAULT_MOCK_BASE_URL, DESKTOP_UA, WINDOWS_PHONE_UA},
    error::{ServiceError, ServiceResult},
    request,
    utils::extract_error,
};
use lazy_static::lazy_static;
use protos::DataModel::{Device, ErrorMessage};
use reqwest::{Client, Method, RequestBuilder, Response, Url, multipart};

fn device_ua(api: &str) -> Cow<'static, str> {
    // Always use windows phone for read.php since it seems to be more robust.
    if api == "read.php" {
        return WINDOWS_PHONE_UA.into();
    }

    let option = request::REQUEST_OPTION.read().unwrap();

    if option.get_random_ua() {
        randua::new().to_string().into()
    } else {
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
}

fn resolve_url(api: &str, mock: bool) -> ServiceResult<Url> {
    let url = Url::parse(api) // if absolute
        .or_else(|_| -> ServiceResult<Url> {
            let base = if mock {
                DEFAULT_MOCK_BASE_URL
            } else {
                let option = request::REQUEST_OPTION.read().unwrap();
                &option.get_base_url_v2().to_owned()
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

async fn do_fetch<AF>(
    api: &str,
    mock: bool,
    mut query: Vec<(&str, &str)>,
    method: Method,
    check_status: bool,
    add_form: AF,
) -> ServiceResult<Response>
where
    AF: FnOnce(RequestBuilder) -> RequestBuilder,
{
    let url = resolve_url(api, mock)?;

    let query = {
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
        .request(method, url)
        .query(&query)
        .header("X-User-Agent", &*device_ua(api));
    let builder = add_form(builder);

    let request = builder.build()?;
    #[cfg(test)]
    println!("request to url: {}", request.url());
    log::info!("request to url: {}", request.url());

    let response = client.execute(request).await?;
    if !check_status || response.status().is_success() {
        Ok(response)
    } else {
        log::error!(
            "request failed: {}",
            response.error_for_status_ref().unwrap_err()
        );
        Err(ServiceError::Mnga(ErrorMessage {
            code: response.status().as_u16().to_string(),
            info: response
                .status()
                .canonical_reason()
                .unwrap_or_default()
                .to_owned(),
            ..Default::default()
        }))
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
    let mut last_error = None;

    // Try different query pairs to mitigate blocking.
    for query_pair in RF::query_pairs() {
        let mut query = query.clone();
        query.push(*query_pair);

        let response = do_fetch(api, false, query, Method::POST, false, &add_form).await?;

        let parse_result = async {
            let response = response.text_with_charset("gb18030").await?;

            #[cfg(test)]
            let _ = RESPONSE_CB.try_with(|c| c.borrow_mut()(&response));
            #[cfg(test)]
            println!("http response: {}", response);

            RF::parse_response(response)
        }
        .await;

        match parse_result {
            Ok(r) => {
                if last_error.is_some() {
                    log::info!(
                        "successfully parsed with `{}={}`",
                        query_pair.0,
                        query_pair.1
                    );
                }
                return Ok(r);
            }
            Err(err) => {
                log::error!(
                    "failed to parse response with `{}={}`, retrying: {}",
                    query_pair.0,
                    query_pair.1,
                    err
                );
                last_error = Some(err);
            }
        }
    }

    log::error!("all query pairs failed, giving up");
    Err(last_error.unwrap())
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
                // ("__output", "9"), // exactly same as `lite=xml`, useless
                ("__output", "10"),
                // TODO: __output=8 yields JSON, which has same schema
            ]
        }

        fn parse_response(response: String) -> ServiceResult<Self> {
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
        let response = do_fetch(&api, true, vec![], Method::GET, true, |b| b)
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
