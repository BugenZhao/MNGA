CARGO = ${HOME}/.cargo/bin/cargo
XARGO = ${HOME}/.cargo/bin/xargo
TARGET = target
OUT_LIBS = out/libs
OUT_LIBS_ANDROID = out/libs/jniLibs
OUT_INCLUDE = out/include

ios-release: swift-pb logic-release-ios logic-bindings
macos-release: swift-pb logic-release-macos logic-bindings

sim-debug: swift-pb logic-bindings
	@echo ">>>>> Logic Simulator"
	${CARGO} build --target x86_64-apple-ios
	cp ${TARGET}/x86_64-apple-ios/debug/liblogic.a ${OUT_LIBS}/liblogicios.a

deploy-release: swift-pb logic-bindings
	@echo ">>>>> Logic aarch64-apple-ios"
	${CARGO} build --release --target aarch64-apple-ios
	cp ${TARGET}/aarch64-apple-ios/release/liblogic.a ${OUT_LIBS}/liblogicios.a

swift-pb:
	@echo ">>>>> Swift PB"
	protoc --swift_out=app/Shared/Protos/ --swift_opt=Visibility=Public -I protos/ protos/*.proto

logic-release-macos:
	@echo ">>>>> Logic macOS"
	${CARGO} lipo --release --targets aarch64-apple-darwin x86_64-apple-darwin
	cp ${TARGET}/universal/release/liblogic.a ${OUT_LIBS}/liblogicmacos.a

logic-release-ios:
	@echo ">>>>> Logic iOS"
	${CARGO} lipo --release
	cp ${TARGET}/universal/release/liblogic.a ${OUT_LIBS}/liblogicios.a

logic-release-catalyst:
	@echo ">>>>> Logic Catalyst"
	${XARGO} build --target x86_64-apple-ios-macabi --release
	cp ${TARGET}/x86_64-apple-ios-macabi/release/liblogic.a ${OUT_LIBS}/liblogiccatalyst.a

logic-debug-macos:
	@echo ">>>>> Logic macOS"
	${CARGO} build
	cp ${TARGET}/debug/liblogic.a ${OUT_LIBS}/liblogicmacos.a

logic-debug-ios:
	@echo ">>>>> Logic iOS"
	${CARGO} lipo
	cp ${TARGET}/universal/debug/liblogic.a ${OUT_LIBS}/liblogicios.a

logic-debug-catalyst:
	@echo ">>>>> Logic Catalyst"
	${XARGO} build --target x86_64-apple-ios-macabi
	cp ${TARGET}/x86_64-apple-ios-macabi/debug/liblogic.a ${OUT_LIBS}/liblogiccatalyst.a

logic-bindings:
	@echo ">>>>> Logic bindings"
	cp logic/logic/bindings.h ${OUT_INCLUDE}

kotlin-pb:
	@echo ">>>>> Kotlin PB"
	protoc --java_out=android --kotlin_out=android -I protos/ protos/*.proto

logic-debug-android:
	@echo ">>>>> Logic Android"
	cd logic && ${CARGO} ndk --target arm64-v8a --target x86_64 --target x86 --platform 26 build
	cp ${TARGET}/aarch64-linux-android/debug/liblogic.so ${OUT_LIBS_ANDROID}/arm64-v8a/
	cp ${TARGET}/x86_64-linux-android/debug/liblogic.so ${OUT_LIBS_ANDROID}/x86_64/
	cp ${TARGET}/i686-linux-android/debug/liblogic.so ${OUT_LIBS_ANDROID}/x86/

logic-release-android:
	@echo ">>>>> Logic Android"
	cd logic && ${CARGO} ndk --target arm64-v8a --target x86_64 --target x86 --platform 26 build --release
	cp ${TARGET}/aarch64-linux-android/release/liblogic.so ${OUT_LIBS_ANDROID}/arm64-v8a/
	cp ${TARGET}/x86_64-linux-android/release/liblogic.so ${OUT_LIBS_ANDROID}/x86_64/
	cp ${TARGET}/i686-linux-android/release/liblogic.so ${OUT_LIBS_ANDROID}/x86/

nightly:
	rustup override set nightly

nightly-unset:
	rustup override unset
