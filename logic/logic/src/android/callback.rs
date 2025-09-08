use crate::callback_trait::CallbackTrait;
use jni::{
    JNIEnv, JavaVM,
    objects::{GlobalRef, JObject, JValue},
};
use service::error::ServiceResult;

pub struct AndroidCallback {
    jvm: JavaVM,
    callback: GlobalRef,
}
unsafe impl Send for AndroidCallback {}

impl AndroidCallback {
    pub fn new(source_env: &JNIEnv, callback: JObject) -> Self {
        let callback = source_env.new_global_ref(callback).unwrap();

        Self {
            jvm: source_env.get_java_vm().unwrap(),
            callback,
        }
    }
}

impl CallbackTrait for AndroidCallback {
    fn id(&self) -> String {
        format!("{:?}", *self.callback.as_obj() as *const _)
    }

    fn run(self, result: ServiceResult<Vec<u8>>) {
        let env = self.jvm.attach_current_thread().unwrap();

        let args: [JValue; 2] = match result {
            Ok(data) => {
                let jdata = env.byte_array_from_slice(&data).unwrap();
                [jdata.into(), JObject::null().into()]
            }
            Err(err) => {
                let jerr = env.new_string(err.to_app_string()).unwrap();
                [JObject::null().into(), jerr.into()]
            }
        };

        env.call_method(
            self.callback.as_obj(),
            "run",
            "([BLjava/lang/String;)V",
            &args,
        )
        .unwrap();
    }
}
