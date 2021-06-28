macro_rules! get {
    ($map:expr, $key:expr) => {
        $map.get($key)?.to_owned()
    };
    ($map:expr, $key:expr, $ty:ty) => {
        $map.get($key)?.parse::<$ty>().ok()?;
    };
    ($map:expr, $key:expr, _) => {
        $map.get($key)?.parse().ok()?;
    };
}

macro_rules! pget {
    ($map:expr, $key:expr) => {
        $map.get($key)?.1.to_owned()
    };
    ($map:expr, $key:expr, $ty:ty) => {
        $map.get($key)?.1.parse::<$ty>().ok()?;
    };
    ($map:expr, $key:expr, _) => {
        $map.get($key)?.1.parse().ok()?;
    };
}

pub(crate) use get;
pub(crate) use pget;
