CARGO ?= $(shell which cargo)
XARGO ?= $(shell which xargo)
SWIFTFORMAT ?= $(shell which swiftformat)
XCBEAUTIFY ?= $(shell which xcbeautify)
XCODE_CONFIGURATION ?= Debug
XCODE_DESTINATION ?= generic/platform=iOS
TARGET_DIR = target
OUT_LIBS_ANDROID ?= out/libs/jniLibs
OUT_INCLUDE ?= out/include

PROCESSOR ?= $(shell uname -p)

ifeq (${PROCESSOR}, arm)
	IOS_SIM_TARGET = aarch64-apple-ios-sim
else
	IOS_SIM_TARGET = x86_64-apple-ios
endif
IOS_TARGET = aarch64-apple-ios
IOS_ALL_TARGETS = ${IOS_TARGET} ${IOS_SIM_TARGET}
MACOS_ALL_TARGETS = aarch64-apple-darwin x86_64-apple-darwin
CATALYST_TARGET = x86_64-apple-ios-macabi

ALL_TARGETS ?= unspecified-target
MODE ?= debug

ifeq (${MODE}, debug)
	CARGO_MODE_ARG = --profile dev
else
	CARGO_MODE_ARG = --profile ${MODE}
endif

ifneq (,$(findstring ios, $(ALL_TARGETS)))
	OUT_FRAMEWORK = out/logic-ios.xcframework
else
	OUT_FRAMEWORK = out/logic-macos.xcframework
endif

.PHONY: logic build

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
		CMD="${CARGO} build --package logic --target $${target} ${CARGO_MODE_ARG}" ;\
		echo ">>> $${CMD}" ;\
		$${CMD} ;\
	done
	@echo ">>>>> Copy bindings"
	cp logic/logic/bindings.h ${OUT_INCLUDE}

build-logic-lipo:
	@echo ">>>>> Build liblogic.a for '${ALL_TARGETS}' in ${MODE} mode using lipo"
	${CARGO} lipo --package logic --targets ${ALL_TARGETS} ${CARGO_MODE_ARG}
	@echo ">>>>> Copy bindings"
	cp logic/logic/bindings.h ${OUT_INCLUDE}

create-framework:
	@echo ">>>>> Create Framework to ${OUT_FRAMEWORK}"
	@CMD="xcodebuild -create-xcframework" ;\
	for target in ${ALL_TARGETS}; do \
		logic_lib="${TARGET_DIR}/$${target}/${MODE}/liblogic.a" ;\
		CMD="$${CMD} -library $${logic_lib}" ;\
	done ;\
	CMD="$${CMD} -headers ${OUT_INCLUDE}/* -output ${OUT_FRAMEWORK}" ;\
	rm -rf ${OUT_FRAMEWORK} ;\
	echo ">>> $${CMD}" ;\
	$${CMD}


kotlin-pb:
	@echo ">>>>> Kotlin PB"
	protoc --java_out=android --kotlin_out=android -I protos/ protos/*.proto

logic-android-%:
	make logic-android MODE=$*
logic-android:
	@echo ">>>>> Build liblogic.so for Android in ${MODE} mode"
	${CARGO} ndk --package logic --target arm64-v8a --target x86_64 --target x86 --platform 26 build ${CARGO_MODE_ARG}
	cp ${TARGET_DIR}/aarch64-linux-android/${MODE}/liblogic.so ${OUT_LIBS_ANDROID}/arm64-v8a/
	cp ${TARGET_DIR}/x86_64-linux-android/${MODE}/liblogic.so ${OUT_LIBS_ANDROID}/x86_64/
	cp ${TARGET_DIR}/i686-linux-android/${MODE}/liblogic.so ${OUT_LIBS_ANDROID}/x86/


swiftformat:
	@if [ -z "${SWIFTFORMAT}" ]; then \
		echo "warning: swiftformat not installed, skip" ;\
	else \
		${SWIFTFORMAT} . ;\
	fi

tuist:
	tuist generate -p app --no-open
clean-xcode-proj:
	rm -rf app/MNGA.xcodeproj app/MNGA.xcworkspace

build:
	@echo ">>>>> Xcode build check for MNGA (${XCODE_CONFIGURATION}) on ${XCODE_DESTINATION}"
	@if [ -n "${XCBEAUTIFY}" ]; then \
		set -o pipefail ;\
		xcodebuild \
			-workspace app/MNGA.xcworkspace \
			-scheme MNGA \
			-configuration ${XCODE_CONFIGURATION} \
			-destination "${XCODE_DESTINATION}" \
			CODE_SIGNING_ALLOWED=NO \
			build | ${XCBEAUTIFY} ;\
	else \
		xcodebuild \
			-workspace app/MNGA.xcworkspace \
			-scheme MNGA \
			-configuration ${XCODE_CONFIGURATION} \
			-destination "${XCODE_DESTINATION}" \
			CODE_SIGNING_ALLOWED=NO \
			build ;\
	fi

nightly:
	rustup override set nightly
nightly-unset:
	rustup override unset
