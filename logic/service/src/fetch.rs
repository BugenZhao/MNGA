#![allow(clippy::declare_interior_mutable_const)]

use std::{borrow::Cow, time::Duration};

use crate::{
    auth,
    constants::{ANDROID_UA, APPLE_UA, DESKTOP_UA, WINDOWS_PHONE_UA},
    error::{ServiceError, ServiceResult},
    request,
    utils::extract_error,
};
use lazy_static::lazy_static;
use protos::DataModel::{Device, ErrorMessage};
use reqwest::{Client, Method, RequestBuilder, Response, Url, multipart};

fn device_ua() -> Cow<'static, str> {
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
            let option = request::REQUEST_OPTION.read().unwrap();
            let base = if mock {
                option.get_mock_base_url_v2()
            } else {
                option.get_base_url_v2()
            };
            let url = Url::parse(&format!("{}/{}", base, api))?;
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

    #[cfg(test)]
    println!("request to url: {}", url);

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
        .header("X-User-Agent", device_ua().as_ref());
    let builder = add_form(builder);

    let response = builder.send().await?;
    if !check_status || response.status().is_success() {
        Ok(response)
    } else {
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
    fn query_pair() -> (&'static str, &'static str);
    fn parse_response(response: String) -> ServiceResult<Self>;
}

async fn do_fetch_text<RF, AF>(
    api: &str,
    mut query: Vec<(&str, &str)>,
    add_form: AF,
) -> ServiceResult<RF>
where
    RF: ResponseFormat,
    AF: FnOnce(RequestBuilder) -> RequestBuilder,
{
    query.push(RF::query_pair());
    let response = do_fetch(api, false, query, Method::POST, false, add_form).await?;
    let response = response.text_with_charset("gb18030").await?;

    #[cfg(test)]
    let _ = RESPONSE_CB.try_with(|c| c.borrow_mut()(&response));

    RF::parse_response(response)
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
        fn query_pair() -> (&'static str, &'static str) {
            ("lite", "xml")
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
        form: multipart::Form,
    ) -> ServiceResult<sxd_document::Package> {
        let auth_info = auth::AUTH_INFO.read().unwrap().clone();
        let form = form
            .percent_encode_path_segment()
            .text("access_token", auth_info.token) // todo: really needed ?
            .text("access_uid", auth_info.uid);

        do_fetch_text(api, query, |b| b.multipart(form)).await
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
