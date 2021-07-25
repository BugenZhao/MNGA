use crate::{
    android::callback::AndroidCallback, callback_trait::CallbackTrait, init::may_init,
    r#async::serve_request_async, sync::serve_request_sync,
};
use jni::{
    objects::{JClass, JObject},
    sys::jbyteArray,
    JNIEnv,
};
use protos::{
    Message,
    Service::{AsyncRequest, SyncRequest},
};

fn parse_from_j<T: Message>(env: &JNIEnv, data: jbyteArray) -> T {
    let bytes = env.convert_byte_array(data).unwrap();
    T::parse_from_bytes(&bytes).expect("invalid request")
}

#[no_mangle]
pub extern "system" fn Java_com_bugenzhao_nga_LogicKt_rustCall(
    env: JNIEnv,
    _: JClass,
    data: jbyteArray,
) -> jbyteArray {
    may_init();
    let request = parse_from_j::<SyncRequest>(&env, data);
    log::info!("request {:?}", request);
    let response_buf = serve_request_sync(request);

    match response_buf {
        Ok(data) => env.byte_array_from_slice(&data).unwrap(),
        Err(err) => {
            env.throw(err.to_string()).unwrap();
            unreachable!()
        }
    }
}

#[no_mangle]
pub extern "system" fn Java_com_bugenzhao_nga_LogicKt_rustCallAsync(
    env: JNIEnv,
    _: JClass,
    data: jbyteArray,
    jcallback: JObject,
) {
    may_init();
    let request = parse_from_j::<AsyncRequest>(&env, data);
    let callback = AndroidCallback::new(&env, jcallback);
    log::info!("async request #{:?} {:?}", callback.id(), request);
    serve_request_async(request, callback);
}
