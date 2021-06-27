#!/bin/sh

echo ">>>>> Swift PB"
protoc --swift_out=app/Shared/ -I protos/ protos/DataModel.proto

echo ">>>>> Rust macOS"
$HOME/.cargo/bin/cargo build --manifest-path logic/Cargo.toml --release
cp logic/target/release/liblogic.a out/libs/liblogicmacos.a
cp logic/bindings.h out/include

echo ">>>>> Rust iOS"
$HOME/.cargo/bin/cargo lipo --manifest-path logic/Cargo.toml --release
cp logic/target/universal/release/liblogic.a out/libs/liblogicios.a
