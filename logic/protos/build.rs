use cargo_emit::rerun_if_changed;
use protoc_rust::Customize;

fn main() {
    rerun_if_changed!("../../protos/Service.proto", "../../protos/DataModel.proto");

    protoc_rust::Codegen::new()
        .out_dir("src/generated")
        .includes(&["../../protos"])
        .inputs(&["../../protos/Service.proto", "../../protos/DataModel.proto"])
        .customize(Customize {
            // serde_derive: Some(true),
            gen_mod_rs: Some(true),
            ..Default::default()
        })
        .run()
        .expect("protoc");
}
