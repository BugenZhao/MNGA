use protobuf::Message;

pub trait MockRequest: Message {
    type Api: Serialize;

    fn is_mock(&self) -> bool;
    fn to_mock_api(&self) -> Self::Api;

    fn to_encoded_mock_api(&self) -> String {
        let api = ron::to_string(&self.to_mock_api()).expect("");
        base_62::encode(api.as_bytes())
    }
}
pub trait MockResponse: Message + Sized {}

mod impls {
    use super::*;
    use crate::Service::*;

    #[derive(Serialize)]
    pub struct TopicListRequestApi {
        id: String,
    }

    impl MockRequest for TopicListRequest {
        type Api = TopicListRequestApi;

        fn is_mock(&self) -> bool {
            self.get_id().get_fid().starts_with("mnga_")
        }

        fn to_mock_api(&self) -> Self::Api {
            Self::Api {
                id: self.get_id().get_fid().to_owned(),
            }
        }
    }
    impl MockResponse for TopicListResponse {}

    #[derive(Serialize)]
    pub struct TopicDetailsRequestApi {
        id: String,
    }

    impl MockRequest for TopicDetailsRequest {
        type Api = TopicDetailsRequestApi;

        fn is_mock(&self) -> bool {
            self.get_topic_id().starts_with("mnga_")
        }

        fn to_mock_api(&self) -> Self::Api {
            Self::Api {
                id: self.get_topic_id().to_owned(),
            }
        }
    }
    impl MockResponse for TopicDetailsResponse {}
}

pub use impls::*;
use serde::Serialize;
