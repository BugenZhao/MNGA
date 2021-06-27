extern crate cbindgen;
extern crate protoc_rust;

use std::env;

use protoc_rust::Customize;

fn main() {
    let crate_dir = env::var("CARGO_MANIFEST_DIR").unwrap();

    cbindgen::Builder::new()
        .with_crate(&crate_dir)
        .with_language(cbindgen::Language::C)
        .generate()
        .expect("Unable to generate bindings")
        .write_to_file("bindings.h");

    protoc_rust::Codegen::new()
        .out_dir("src/protos")
        .includes(&["../protos"])
        .inputs(&["../protos/DataModel.proto"])
        .customize(Customize {
            gen_mod_rs: Some(true),
            ..Default::default()
        })
        .run()
        .expect("protoc");
}
