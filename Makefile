CARGO = ${HOME}/.cargo/bin/cargo
OUT_LIBS = out/libs
OUT_INCLUDE = out/include

release: swift-pb logic-release

debug: swift-pb logic-debug

swift-pb:
	@echo ">>>>> Swift PB"
	protoc --swift_out=app/Shared/Protos/ -I protos/ protos/*.proto

logic-release:
	@echo ">>>>> Logic macOS"
	${CARGO} build --manifest-path logic/Cargo.toml --release
	cp logic/target/release/liblogic.a ${OUT_LIBS}/liblogicmacos.a
	@echo ">>>>> Logic iOS"
	${CARGO} lipo --manifest-path logic/Cargo.toml --release
	cp logic/target/universal/release/liblogic.a ${OUT_LIBS}/liblogicios.a
	@make logic-bindings

logic-debug:
	@echo ">>>>> Logic macOS"
	${CARGO} build --manifest-path logic/Cargo.toml
	cp logic/target/debug/liblogic.a ${OUT_LIBS}/liblogicmacos.a
	cp logic/bindings.h ${OUT_INCLUDE}
	@echo ">>>>> Logic iOS"
	${CARGO} lipo --manifest-path logic/Cargo.toml
	cp logic/target/universal/debug/liblogic.a ${OUT_LIBS}/liblogicios.a
	@make logic-bindings

logic-bindings:
	@echo ">>>>> Logic bindings"
	cp logic/bindings.h ${OUT_INCLUDE}
