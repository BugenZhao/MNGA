<h1 align="center">MNGA

<!-- [![Logic](https://github.com/BugenZhao/NGA/actions/workflows/logic.yaml/badge.svg)](https://github.com/BugenZhao/NGA/actions/workflows/logic.yaml) -->

</h1>

<h3 align="center">A refreshing NGA Forum App in SwiftUI.</h3>

<p align="center">
<img src="assets/MNGA-liquid-glass-compressed.png" width="256"></img>
</p>

<h4 align="center">Make NGA Great Again.</h4>

## Get the App

- App Store

  <a href="https://apps.apple.com/cn/app/mnga/id1586461246">
  <img src="https://user-images.githubusercontent.com/25862682/147930330-3076005c-7525-452b-abcf-bef264f7e462.png" width="200"></img></a>

<!-- - TestFlight Public Link

  <a href="https://testflight.apple.com/join/UL8mvVKt">
  <img src="https://user-images.githubusercontent.com/25862682/133919629-0f337486-7ef2-4a34-9b36-a09e3b838ca8.png" width="200"></img></a> -->

- Or build the project yourself, check instructions below.

## Features

- Built with SwiftUI which provides awesome UX feelings for **multiple platforms** including iOS, iPadOS and macOS
- High-performance logic layer energized by Rust (and can be ported to other platforms with ease, check [Android Instructions](android/README.md))

## Screenshots

### iOS

<p align="center">
  <img width="32%" src="https://github.com/user-attachments/assets/867459e7-04a7-45bc-9f11-777d7cb49596" />
  <img width="32%" src="https://github.com/user-attachments/assets/700b5c86-7c6c-4ec6-8499-594da3dd5572" />
  <img width="32%" src="https://github.com/user-attachments/assets/e6c70147-1f4f-4482-845d-cc7803d8718b" />
  <img width="32%" src="https://github.com/user-attachments/assets/8b2f8ff9-2dce-4f6f-9ec8-04a0ae95fcf9" />
  <img width="32%" src="https://github.com/user-attachments/assets/2974faef-1eea-4bc2-b097-7662fb8ab941" />
  <img width="32%" src="https://github.com/user-attachments/assets/5f9fcabb-904b-465e-b2b1-aa98351bceeb" />
  <img width="32%" src="https://github.com/user-attachments/assets/64e841fd-1bf0-4971-a3a0-b7fa116bc9fc" />
  <img width="32%" src="https://github.com/user-attachments/assets/afc2bdda-08bc-4da8-9988-bc5fa86ad050" />
  <img width="32%" src="https://github.com/user-attachments/assets/85854f32-e8f6-4269-b0ae-2da8b1fdac94" />
</p>

### iPadOS

<p align="center">
  <img src="https://github.com/user-attachments/assets/1a0049aa-41cb-46d0-bd8a-f106792fa956"/>
</p>

<!-- ### macOS

<p align="center">
  <img src="https://user-images.githubusercontent.com/25862682/136158065-d6df1506-6192-4360-9d96-d850126ae339.png"/>
</p> -->

## Build the Project

1. Install Xcode and Rust toolchains. Make sure you have set your command line tools location correctly by

   安装 Xcode 及 Rust 相关工具链。确保 CLI 工具的路径设置正确：

   ```bash
   $ sudo xcode-select --switch /Applications/Xcode.app
   ```

2. Install other prerequisites.

   安装其他依赖。

   ```bash
   $ brew install swift-protobuf tuist
   $ cargo install cargo-lipo

   $ rustup target add aarch64-apple-ios
   $ rustup target add aarch64-apple-ios-sim
   ```

3. Clone the repository and run at the project root:

   克隆仓库到本地，在项目的根目录，运行

   ```bash
   $ make ios
   $ make tuist
   ```

   You'll find `logic-ios.xcframework` under `out`.

   检查 `out` 目录，将会生成 `logic-ios.xcframework` Xcode Framework.

4. Open the Xcode project `app/NGA.xcodeproj`. Build and run the app after you set the correct Developer Profile.

   打开 Xcode 工程 `app/NGA.xcodeproj`，重新设置 Developer Profile 后，编译运行 MNGA。

<!-- ## Donation

如果你喜欢 MNGA，欢迎通过下面的二维码捐赠支持。由于 NGA 官方封锁限制不断加深，我们只能尽最大努力来维持 App 的基本可用性，对于一些无能为力的问题还请谅解，谢谢。

<p align="center">
<img src="https://user-images.githubusercontent.com/25862682/194579914-d27a025c-f00a-44d6-b0e6-ec73f8d16fb9.PNG" width="300"></img>
</p> -->

## Statements

- 本项目中涉及的 NGA 等文字，NGA 版块、帖子、用户等数据，AC 娘表情等资源，其版权均归 NGA BBS (https://ngabbs.com) 所有。
- This project _currently_ has NO LICENSE. You MAY NOT modify or redistribute this code without explicit permission.

[nightly-link]: https://testflight.apple.com/join/UL8mvVKt
[as-image]: https://user-images.githubusercontent.com/25862682/147930330-3076005c-7525-452b-abcf-bef264f7e462.png
