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

pub(crate) use get;
