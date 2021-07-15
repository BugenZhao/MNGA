#[cfg(test)]
#[path = "auth_debug.rs"]
mod auth;
#[cfg(not(test))]
mod auth;
mod constants;
mod dispatch;
pub mod error;
mod fetch;
mod forum;
mod history;
mod macros;
mod post;
mod topic;
mod user;
mod utils;

use fetch::fetch_package;

pub use dispatch::*;
