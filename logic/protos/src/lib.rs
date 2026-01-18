#[allow(clippy::all)]
#[allow(mismatched_lifetime_syntaxes)]
#[allow(renamed_and_removed_lints)]
#[allow(unused_parens)]
#[rustfmt::skip]
mod generated;

mod mock;
mod to_value;

pub use generated::*;
pub use mock::*;
pub use to_value::*;

pub use protobuf::Message;
pub use protobuf::ProtobufEnum;
pub use protobuf::ProtobufError;

mod impls {
    use std::fmt::Display;

    use crate::DataModel::ErrorMessage;

    impl Display for ErrorMessage {
        fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
            if self.code.is_empty() {
                write!(f, "{}", self.info)
            } else {
                write!(f, "{} ({})", self.info, self.code)
            }
        }
    }
}
