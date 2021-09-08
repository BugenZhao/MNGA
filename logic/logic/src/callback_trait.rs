use service::error::ServiceResult;

pub trait CallbackTrait: Send + 'static {
    fn id(&self) -> String;
    fn run(self, result: ServiceResult<Vec<u8>>);
}
