extern crate protoc_rust;

use protoc_rust::Customize;

fn main() {
    println!("cargo:rerun-if-changed=build.rs");
    println!("cargo:rerun-if-changed=../Cargo.lock");
    println!("cargo:rerun-if-changed=../../protos/*");

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
