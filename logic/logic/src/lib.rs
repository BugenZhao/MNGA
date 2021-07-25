mod r#async;
mod callback_trait;
mod init;
mod sync;

#[cfg(target_os = "android")]
mod android;
#[cfg(not(target_os = "android"))]
mod c;
