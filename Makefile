CARGO = ${HOME}/.cargo/bin/cargo
XARGO = ${HOME}/.cargo/bin/xargo
OUT_LIBS = out/libs
OUT_INCLUDE = out/include

release: swift-pb logic-release

debug: swift-pb logic-debug

swift-pb:
	@echo ">>>>> Swift PB"
	protoc --swift_out=app/Shared/Protos/ -I protos/ protos/*.proto

logic-release: logic-release-ios logic-bindings

logic-release-macos:
	@echo ">>>>> Logic macOS"
	${CARGO} build --manifest-path logic/Cargo.toml --release
	cp logic/target/release/liblogic.a ${OUT_LIBS}/liblogicmacos.a

logic-release-ios:
	@echo ">>>>> Logic iOS"
	${CARGO} lipo --manifest-path logic/Cargo.toml --release
	cp logic/target/universal/release/liblogic.a ${OUT_LIBS}/liblogicios.a

logic-release-catalyst:
	@echo ">>>>> Logic Catalyst"
	${XARGO} build --target x86_64-apple-ios-macabi --manifest-path logic/Cargo.toml --release
	cp logic/target/x86_64-apple-ios-macabi/release/liblogic.a ${OUT_LIBS}/liblogiccatalyst.a

logic-debug: logic-debug-ios logic-bindings

logic-debug-macos:
	@echo ">>>>> Logic macOS"
	${CARGO} build --manifest-path logic/Cargo.toml
	cp logic/target/debug/liblogic.a ${OUT_LIBS}/liblogicmacos.a

logic-debug-ios:
	@echo ">>>>> Logic iOS"
	${CARGO} lipo --manifest-path logic/Cargo.toml
	cp logic/target/universal/debug/liblogic.a ${OUT_LIBS}/liblogicios.a

logic-debug-catalyst:
	@echo ">>>>> Logic Catalyst"
	${XARGO} build --target x86_64-apple-ios-macabi --manifest-path logic/Cargo.toml
	cp logic/target/x86_64-apple-ios-macabi/debug/liblogic.a ${OUT_LIBS}/liblogiccatalyst.a

logic-bindings:
	@echo ">>>>> Logic bindings"
	cp logic/bindings.h ${OUT_INCLUDE}

nightly:
	rustup override set nightly

nightly-unset:
	rustup override unset
