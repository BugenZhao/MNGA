<h1 align="center">MNGA

[![Logic](https://github.com/BugenZhao/NGA/actions/workflows/logic.yaml/badge.svg)](https://github.com/BugenZhao/NGA/actions/workflows/logic.yaml)

</h1>

<h3 align="center">A refreshing NGA Forum App in SwiftUI.</h3>

<p align="center">
<img src="app/Shared/Assets.xcassets/RoundedIcon.imageset/RoundedIcon-Mac.png" width="256"></img>
</p>

<h4 align="center">Make NGA Great Again.</h4>

## Get the App

- App Store

  <a href="https://apps.apple.com/cn/app/mnga/id1586461246">
  <img src="https://user-images.githubusercontent.com/25862682/147930330-3076005c-7525-452b-abcf-bef264f7e462.png" width="200"></img></a>

- TestFlight Public Link for iOS

  | Stable Channel （稳定版）  | Nightly Channel （开发版）  |
  | -------------------------- | --------------------------- |
  | [![tf-image]][stable-link] | [![tf-image]][nightly-link] |

- Or build the project yourself, check instructions below.

## Donation

如果你喜欢 MNGA，欢迎通过下面的二维码捐赠支持。由于 NGA 官方封锁限制不断加深，我们只能尽最大努力来维持 App 的基本可用性，对于一些无能为力的问题还请谅解，谢谢。

<p align="center">
<img src="https://user-images.githubusercontent.com/25862682/194579914-d27a025c-f00a-44d6-b0e6-ec73f8d16fb9.PNG" width="300"></img>
</p>

## Features

- Built with SwiftUI which provides awesome UX feelings for **multiple platforms** like iOS, iPadOS and macOS
- High-performance logic layer energized by Rust (and can be ported to other platforms with ease, check [Android Instructions](android/README.md))

## Screenshots

### iOS

<p align="center">
  <img src="https://user-images.githubusercontent.com/25862682/145673784-f079df83-741e-4f95-91bd-58cbea256e00.PNG" width="32%" />
  <img src="https://user-images.githubusercontent.com/25862682/145673788-dcc7fd14-533b-4bad-9ee7-a4dc9fd786f0.PNG" width="32%" />
  <img src="https://user-images.githubusercontent.com/25862682/145674014-bab62ff3-f7d9-4787-bc0a-7ea79b840d3e.PNG" width="32%" />
  <img src="https://user-images.githubusercontent.com/25862682/145673806-7f2ee397-dc99-49d4-9470-9b7c885fd7bb.PNG" width="32%" />
  <img src="https://user-images.githubusercontent.com/25862682/145674986-dc7447d8-9d4a-42e9-89df-1653d0812a43.PNG" width="32%" />
  <img src="https://user-images.githubusercontent.com/25862682/145673808-e1a295fc-c90d-4dd0-bdef-ed500fd29f9a.PNG" width="32%" />
  <img src="https://user-images.githubusercontent.com/25862682/145673820-94fdace7-10be-4c7d-beb3-0676ebf20951.PNG" width="32%" />
  <img src="https://user-images.githubusercontent.com/25862682/145673816-bd74b0dd-7d89-4470-ab4c-76bb8000e15b.PNG" width="32%" />
  <img src="https://user-images.githubusercontent.com/25862682/145673812-3e221651-0824-4545-b8c8-93b860227838.PNG" width="32%" />
</p>

### iPadOS

<p align="center">
  <img src="https://user-images.githubusercontent.com/25862682/145675012-50ad7b2d-e841-4788-9505-b1a299c05df3.PNG"/>
</p>

### macOS

<p align="center">
  <img src="https://user-images.githubusercontent.com/25862682/136158065-d6df1506-6192-4360-9d96-d850126ae339.png"/>
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
[as-image]: https://user-images.githubusercontent.com/25862682/147930330-3076005c-7525-452b-abcf-bef264f7e462.png
