#![allow(unused)]

pub const DEFAULT_BASE_URL: &str = "https://nga.178.com";
pub const DEFAULT_MOCK_BASE_URL: &str =
    "https://raw.githubusercontent.com/BugenZhao/MNGA/gh-pages/api/";
pub const DEFAULT_PROXY_BASE_URL: &str = "https://nga.bugenzhao.com";
pub const FORUM_ICON_PATH: &str = "http://img4.ngacn.cc/ngabbs/nga_classic/f/app/";
pub const MNGA_ICON_PATH: &str = "https://raw.githubusercontent.com/BugenZhao/MNGA/main/app/Shared/Assets.xcassets/RoundedIcon.imageset/RoundedIcon-Mac.png";

pub const SUCCESS_MSGS: &[&str] = &["完毕", "没找到", "没有符合条件的结果", "今天已经签到"];

pub const APPLE_UA: &str = "NGA_skull/7.3.1(iPhone13,2;iOS 15.5)";
pub const ANDROID_UA: &str = "Nga_Official/80024(Android12)";
pub const DESKTOP_UA: &str = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/101.0.4951.64 Safari/537.36";
pub const WINDOWS_PHONE_UA: &str = "NGA_WP_JW/(;WINDOWS)";

#[cfg(test)]
pub const REVIEW_UID: &str = "62650766";
