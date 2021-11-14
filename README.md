<h1 align="center">MNGA

[![Logic](https://github.com/BugenZhao/NGA/actions/workflows/logic.yaml/badge.svg)](https://github.com/BugenZhao/NGA/actions/workflows/logic.yaml)

</h1>

<h3 align="center">A refreshing NGA Forum App in SwiftUI.</h3>

<p align="center">
<img src="app/Shared/Assets.xcassets/RoundedIcon.imageset/RoundedIcon-Mac.png" width="256"></img>
</p>

<h4 align="center">Make NGA Great Again.</h4>

## Get the App

- TestFlight Public Link for iOS

  | Stable Channel （稳定版）  | Nightly Channel （开发版）  |
  | -------------------------- | --------------------------- |
  | [![tf-image]][stable-link] | [![tf-image]][nightly-link] |

- Or build the project yourself, check instructions below.

## Features

- Built with SwiftUI which provides awesome UX feelings for **multiple platforms** like iOS, iPadOS and macOS
- High-performance logic layer energized by Rust (and can be ported to other platforms with ease, check [Android Instructions](android/README.md))

## Screenshots

### iOS

<p align="center">
  <img src="https://user-images.githubusercontent.com/25862682/135757461-8d85b17e-452b-4006-86bc-e0f122c7f59b.PNG" width="32%" />
  <img src="https://user-images.githubusercontent.com/25862682/126900260-55949320-f6a9-4cab-a098-cc02edefdc1f.PNG" width="32%" />
  <img src="https://user-images.githubusercontent.com/25862682/135757470-91a3539e-71fb-4d4c-b42d-5cf096b99eb1.PNG" width="32%" />
  <img src="https://user-images.githubusercontent.com/25862682/126900264-726e5878-a1e0-4f38-b64a-9e9d76bf3206.PNG" width="32%" />
  <img src="https://user-images.githubusercontent.com/25862682/133466845-2c65b772-485b-483e-8e30-f0d36c292510.PNG" width="32%" />
  <img src="https://user-images.githubusercontent.com/25862682/135757485-65a8427b-7b55-4dbe-b91a-3f133ec1e303.PNG" width="32%" />
  <img src="https://user-images.githubusercontent.com/25862682/133466841-047bef9a-b39f-4951-a9a6-6be14f8a7c35.PNG" width="32%" />
  <img src="https://user-images.githubusercontent.com/25862682/133466833-c81aac7b-18f7-4238-8123-7f8445287563.PNG" width="32%" />
  <img src="https://user-images.githubusercontent.com/25862682/135757479-20c416c7-fe66-4ddd-83a7-f97c5d1a8878.PNG" width="32%" />
</p>

### iPadOS

<p align="center">
  <img src="https://user-images.githubusercontent.com/25862682/136158984-cee02ee8-c3d2-4bb6-a302-6fcb2a219c57.PNG" width="96%"/>
</p>

### macOS

<p align="center">
  <img src="https://user-images.githubusercontent.com/25862682/136158065-d6df1506-6192-4360-9d96-d850126ae339.png" width="100%"/>
</p>

## Build the Project

1. Install Xcode and Rust toolchains. Make sure you have set your command line tools location correctly by

   安装 Xcode 及 Rust 相关工具链。确保 CLI 工具的路径设置正确：

   ```bash
   $ sudo xcode-select --switch /Applications/Xcode.app
   ```

2. Install other prerequisites.

   安装其他依赖。

   ```bash
   $ brew install swift-protobuf
   $ cargo install cargo-lipo

   $ rustup target add aarch64-apple-ios
   $ rustup target add aarch64-apple-ios-sim  # optional: Simulator target for Apple Silicon
   $ rustup target add x86_64-apple-ios       # optional: Simulator target for Intel
   $ rustup target add aarch64-apple-darwin   # optional: macOS target for Apple Silicon
   $ rustup target add x86_64-apple-darwin    # optional: macOS target for Intel
   ```

3. Clone the repository and run at the project root:

   克隆仓库到本地，在项目的根目录，运行

   ```bash
   $ make ios
   $ make macos
   ```

   You'll find `logic-ios.xcframework` and `logic-macos.xcframework` under `out`.

   检查 `out` 目录，将会生成 `logic-ios.xcframework` 和 `logic-macos.xcframework` 两个 Xcode Framework.

4. Open the Xcode project `app/NGA.xcodeproj`. Run the app after you set the correct Apple ID.

   打开 Xcode 工程 `app/NGA.xcodeproj`，重新设置签名 Apple ID 后，编译运行 MNGA。

## Statements

- 本项目中涉及的 NGA 等文字，NGA 版块、帖子、用户等数据，AC 娘表情等资源，其版权均归 NGA BBS (https://ngabbs.com) 所有。
- This project _currently_ has NO LICENSE. You MAY NOT modify or redistribute this code without explicit permission.

[stable-link]: https://testflight.apple.com/join/w9duC4Du
[nightly-link]: https://testflight.apple.com/join/UL8mvVKt
[tf-image]: https://user-images.githubusercontent.com/25862682/133919629-0f337486-7ef2-4a34-9b36-a09e3b838ca8.png
