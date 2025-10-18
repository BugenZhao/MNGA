import ProjectDescription

let project = Project(
    name: "MNGA",
    // TODO: avoid using exact requirements
    packages: [
        .remote(url: "https://github.com/apple/swift-protobuf", requirement: .exact("1.31.0")),
        .remote(url: "https://github.com/SDWebImage/SDWebImageSwiftUI", requirement: .exact("2.2.6")),
        .remote(url: "https://github.com/SDWebImage/SDWebImageWebPCoder.git", requirement: .exact("0.14.6")),
        .remote(url: "https://github.com/SwiftUIX/SwiftUIX", requirement: .exact("0.2.4")),
        .remote(url: "https://github.com/kylehickinson/SwiftUI-WebView", requirement: .exact("0.3.0")),
        .remote(url: "https://github.com/apple/swift-log", requirement: .exact("1.5.3")),
        .remote(url: "https://github.com/stleamist/BetterSafariView", requirement: .exact("2.4.2")),
        .remote(url: "https://github.com/chackle/Colorful", requirement: .exact("1.0.0")),
        .remote(url: "https://github.com/CombineCommunity/CombineExt", requirement: .exact("1.8.1")),
    //  .local(path: "../../AlertToast"),
        .remote(url: "https://github.com/BugenZhao/AlertToast", requirement: .revision("668a60ea241735d78f4f26a63d9fb714f20564ce")),
        .remote(url: "https://github.com/giginet/Crossroad", requirement: .exact("3.2.0")),
        .remote(url: "https://github.com/siteline/SwiftUI-Introspect", requirement: .exact("26.0.0-rc.1")),
        .remote(url: "https://github.com/krzysztofzablocki/Inject.git", requirement: .exact("1.5.2")),
        .remote(url: "https://github.com/gh123man/LazyPager", requirement: .exact("1.1.13")),
        .remote(url: "https://github.com/tevelee/SwiftUI-Flow", requirement: .exact("3.1.0")),
        .remote(url: "https://github.com/SvenTiigi/WhatsNewKit.git", requirement: .exact("2.2.1")),
        .remote(url: "https://github.com/apple/swift-collections", requirement: .exact("1.3.0")),
    ],
    targets: [
        // iOS App Target
        .target(
            name: "MNGA",
            destinations: .iOS,
            product: .app,
            bundleId: "com.bugenzhao.MNGA",
            deploymentTargets: .iOS("26.0"),
            infoPlist: .file(path: "iOS/Info.plist"),
            sources: [
                "Shared/**",
                "iOS/**",
            ],
            resources: [
                "Shared/Assets.xcassets",
                "Shared/Localization/**",
                "MNGA.icon",
            ],
            entitlements: "MNGA.entitlements",
            dependencies: [
                .package(product: "SwiftProtobuf"),
                .package(product: "SDWebImageSwiftUI"),
                .package(product: "SDWebImageWebPCoder"),
                .package(product: "SwiftUIX"),
                .package(product: "WebView"),
                .package(product: "Logging"),
                .package(product: "BetterSafariView"),
                .package(product: "Colorful"),
                .package(product: "CombineExt"),
                .package(product: "AlertToast"),
                .package(product: "Crossroad"),
                .package(product: "SwiftUIIntrospect"),
                .package(product: "Inject"),
                .package(product: "LazyPager"),
                .package(product: "Flow"),
                .package(product: "WhatsNewKit"),
                .package(product: "Collections"),
                .xcframework(path: "../out/logic-ios.xcframework"),
            ],
            settings: .settings(
                base: [
                    "ASSETCATALOG_COMPILER_APPICON_NAME": "MNGA",
                    "MARKETING_VERSION": "2.1",
                    "CURRENT_PROJECT_VERSION": "1",
                    "SWIFT_VERSION": "5.0",
                    "ENABLE_BITCODE": "NO",
                    "SWIFT_OBJC_BRIDGING_HEADER": "../out/include/bindings.h",
                    "LIBRARY_SEARCH_PATHS": "../out/libs/**",
                    "DEVELOPMENT_TEAM": "87F9J2DF6R",
                    "SUPPORTS_MACCATALYST": "NO",
                    "SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD": "YES",
                ],
                configurations: [
                    .debug(name: .debug, settings: [
                        "CODE_SIGN_IDENTITY": "Apple Development",
                        "PROVISIONING_PROFILE_SPECIFIER": "match Development com.bugenzhao.MNGA",
                        "OTHER_LDFLAGS[sdk=iphonesimulator*]": ["-Xlinker", "-interposable"],
                        "EMIT_FRONTEND_COMMAND_LINES": "YES",
                    ]),
                    .release(name: .release, settings: [
                        "CODE_SIGN_IDENTITY": "Apple Distribution",
                        "PROVISIONING_PROFILE_SPECIFIER": "match AppStore com.bugenzhao.MNGA",
                    ]),
                ]
            )
        ),

        // macOS App Target - Temporarily disabled
        // .target(
        //     name: "MNGA-macOS",
        //     destinations: .macOS,
        //     product: .app,
        //     bundleId: "com.bugenzhao.MNGA",
        //     deploymentTargets: .macOS("26.0"),
        //     infoPlist: .file(path: "macOS/Info.plist"),
        //     sources: [
        //         "Shared/**",
        //         "macOS/**",
        //     ],
        //     resources: [
        //         "Shared/Assets.xcassets",
        //         "Shared/Localization/**",
        //     ],
        //     entitlements: "macOS/macOS.entitlements",
        //     dependencies: [
        //         .xcframework(path: "out/logic-macos.xcframework"),
        //     ],
        //     settings: .settings(
        //         base: [
        //             "MARKETING_VERSION": "1.1.2",
        //             "CURRENT_PROJECT_VERSION": "1",
        //             "SWIFT_VERSION": "5.0",
        //             "SWIFT_OBJC_BRIDGING_HEADER": "../out/include/bindings.h",
        //             "LIBRARY_SEARCH_PATHS": "../out/libs/**",
        //             "CODE_SIGN_IDENTITY": "-",
        //             "ENABLE_APP_SANDBOX": "YES",
        //             "ENABLE_HARDENED_RUNTIME": "YES",
        //             "ENABLE_OUTGOING_NETWORK_CONNECTIONS": "YES",
        //             "ENABLE_USER_SELECTED_FILES": "readonly",
        //         ],
        //         configurations: [
        //             .debug(name: .debug),
        //             .release(name: .release),
        //         ]
        //     )
        // ),
    ]
)
