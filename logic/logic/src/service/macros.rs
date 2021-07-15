macro_rules! get {
    ($map:expr, $key:expr) => {
        $map.get($key).cloned()
    };
    ($map:expr, $key:expr, $ty:ty) => {
        $map.get($key).map(|a| a.parse::<$ty>().ok()).flatten()
    };
    ($map:expr, $key:expr, _) => {
        $map.get($key).map(|a| a.parse().ok()).flatten()
    };
}

macro_rules! pget {
    ($map:expr, $idx:expr) => {
        $map.get($idx).cloned().map(|p| p.1)
    };
    ($map:expr, $idx:expr, $ty:ty) => {
        $map.get($idx).map(|p| p.1.parse::<$ty>().ok()).flatten()
    };
    ($map:expr, $idx:expr, _) => {
        $map.get($idx).map(|p| p.1.parse().ok()).flatten()
    };
}

pub(crate) use get;
pub(crate) use pget;
