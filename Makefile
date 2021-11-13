CARGO = $(shell which cargo)
XARGO = $(shell which xargo)
TARGET_DIR = target
OUT_LIBS_ANDROID = out/libs/jniLibs
OUT_INCLUDE = out/include

PROCESSOR = $(shell uname -p)

ifeq (${PROCESSOR}, arm)
	IOS_SIM_TARGET = aarch64-apple-ios-sim
else
	IOS_SIM_TARGET = x86_64-apple-ios
endif
IOS_TARGET = aarch64-apple-ios
IOS_ALL_TARGETS = ${IOS_TARGET} ${IOS_SIM_TARGET}
MACOS_ALL_TARGETS = aarch64-apple-darwin x86_64-apple-darwin
CATALYST_TARGET = x86_64-apple-ios-macabi

ALL_TARGETS = unspecified-target
MODE ?= debug

ifeq (${MODE}, release)
	CARGO_MODE_ARG = --release
else
	CARGO_MODE_ARG =
endif

ifneq (,$(findstring ios, $(ALL_TARGETS)))
	OUT_FRAMEWORK = out/logic-ios.xcframework
else
	OUT_FRAMEWORK = out/logic-macos.xcframework
endif

.PHONY: logic

ios: logic-ios-release
macos: logic-macos-release

logic-ios-%:
	make logic-ios MODE=$*
logic-ios:
	make logic ALL_TARGETS="${IOS_ALL_TARGETS}"

logic-sim:
	make logic ALL_TARGETS="${IOS_SIM_TARGET}" MODE=debug
logic-deploy:
	make logic ALL_TARGETS="${IOS_TARGET}" MODE=release

logic-macos-%:
	make logic-macos MODE=$*
logic-macos:
	make logic-lipo ALL_TARGETS="${MACOS_ALL_TARGETS}"

logic-catalyst-%:
	make logic-catalyst MODE=$*
logic-catalyst:
	make logic ALL_TARGETS="${CATALYST_TARGET}"


logic: swift-pb build-logic create-framework
logic-lipo:
	@make swift-pb
	@make build-logic-lipo
	@make create-framework ALL_TARGETS=universal

swift-pb:
	@echo ">>>>> Swift PB"
	protoc --swift_out=app/Shared/Protos/ --swift_opt=Visibility=Public -I protos/ protos/*.proto

build-logic:
	@echo ">>>>> Build liblogic.a for '${ALL_TARGETS}' in ${MODE} mode"
	@for target in ${ALL_TARGETS}; do \
		CMD="${CARGO} build --target $${target} ${CARGO_MODE_ARG}" ;\
		echo ">>> $${CMD}" ;\
		$${CMD} ;\
	done
	@echo ">>>>> Copy bindings"
	cp logic/logic/bindings.h ${OUT_INCLUDE}

build-logic-lipo:
	@echo ">>>>> Build liblogic.a for '${ALL_TARGETS}' in ${MODE} mode using lipo"
	${CARGO} lipo --targets ${ALL_TARGETS} ${CARGO_MODE_ARG}
	@echo ">>>>> Copy bindings"
	cp logic/logic/bindings.h ${OUT_INCLUDE}

create-framework:
	@echo ">>>>> Create Framework to ${OUT_FRAMEWORK}"
	@CMD="xcodebuild -create-xcframework" ;\
	for target in ${ALL_TARGETS}; do \
		logic_lib="${TARGET_DIR}/$${target}/${MODE}/liblogic.a" ;\
		strip_cmd="strip $${logic_lib}" ;\
		echo ">>> $${strip_cmd}" ;\
		$${strip_cmd} >/dev/null 2>&1 || exit 1;\
		CMD="$${CMD} -library $${logic_lib}" ;\
	done ;\
	CMD="$${CMD} -headers ${OUT_INCLUDE}/* -output ${OUT_FRAMEWORK}" ;\
	rm -rf ${OUT_FRAMEWORK} ;\
	echo ">>> $${CMD}" ;\
	$${CMD}


kotlin-pb:
	@echo ">>>>> Kotlin PB"
	protoc --java_out=android --kotlin_out=android -I protos/ protos/*.proto

logic-debug-android:
	@echo ">>>>> Logic Android"
	cd logic && ${CARGO} ndk --target arm64-v8a --target x86_64 --target x86 --platform 26 build
	cp ${TARGET_DIR}/aarch64-linux-android/debug/liblogic.so ${OUT_LIBS_ANDROID}/arm64-v8a/
	cp ${TARGET_DIR}/x86_64-linux-android/debug/liblogic.so ${OUT_LIBS_ANDROID}/x86_64/
	cp ${TARGET_DIR}/i686-linux-android/debug/liblogic.so ${OUT_LIBS_ANDROID}/x86/
logic-release-android:
	@echo ">>>>> Logic Android"
	cd logic && ${CARGO} ndk --target arm64-v8a --target x86_64 --target x86 --platform 26 build --release
	cp ${TARGET_DIR}/aarch64-linux-android/release/liblogic.so ${OUT_LIBS_ANDROID}/arm64-v8a/
	cp ${TARGET_DIR}/x86_64-linux-android/release/liblogic.so ${OUT_LIBS_ANDROID}/x86_64/
	cp ${TARGET_DIR}/i686-linux-android/release/liblogic.so ${OUT_LIBS_ANDROID}/x86/


nightly:
	rustup override set nightly
nightly-unset:
	rustup override unset
