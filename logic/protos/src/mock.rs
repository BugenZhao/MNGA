use protobuf::{Message, ProtobufResult};

use crate::Service::MockApi;

pub fn encode_api(api: &MockApi) -> ProtobufResult<String> {
    let bytes = api.write_to_bytes()?.to_vec();
    Ok(base_62::encode(&bytes))
}

pub trait MockRequest: Message {
    fn is_mock(&self) -> bool;
    fn to_mock_api(&self) -> MockApi;

    fn to_encoded_mock_api(&self) -> ProtobufResult<String> {
        encode_api(&self.to_mock_api())
    }
}
pub trait MockResponse: Message + Sized {}

#[macro_export]
macro_rules! mock_api {
    ($set:ident, $value:expr) => {{
        let mut api = $crate::Service::MockApi::new();
        api.$set($value);
        api
    }};
}

mod impls {
    use super::*;
    use crate::Service::*;

    impl MockRequest for TopicListRequest {
        fn is_mock(&self) -> bool {
            self.get_id().get_fid().starts_with("mnga_")
        }

        fn to_mock_api(&self) -> MockApi {
            mock_api!(
                set_topic_list,
                MockApi_TopicList {
                    id: self.get_id().get_fid().to_owned(),
                    ..Default::default()
                }
            )
        }
    }
    impl MockResponse for TopicListResponse {}

    impl MockRequest for TopicDetailsRequest {
        fn is_mock(&self) -> bool {
            self.get_topic_id().starts_with("mnga_")
        }

        fn to_mock_api(&self) -> MockApi {
            mock_api!(
                set_topic_details,
                MockApi_TopicDetails {
                    id: self.get_topic_id().to_owned(),
                    ..Default::default()
                }
            )
        }
    }
    impl MockResponse for TopicDetailsResponse {}
}
