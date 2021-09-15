# MNGA

[![Logic](https://github.com/BugenZhao/NGA/actions/workflows/logic.yaml/badge.svg)](https://github.com/BugenZhao/NGA/actions/workflows/logic.yaml)

> **M**ake **N**GA **G**reat **A**gain.

An NGA App in SwiftUI with cross-platform logic in Rust.

## App Store & TestFlight

###### Coming soon

## Features

- Built with SwiftUI which provides awesome UX feelings
- High-performance logic layer energized by Rust (and can be ported to other platforms with ease, check [Android Examples](android/README.md))

## Screenshots

<p align="middle">
  <img src="https://user-images.githubusercontent.com/25862682/126900256-1a8d23de-805f-498e-960f-be3d2304146b.PNG" width="32%" />
  <img src="https://user-images.githubusercontent.com/25862682/126900260-55949320-f6a9-4cab-a098-cc02edefdc1f.PNG" width="32%" />
  <img src="https://user-images.githubusercontent.com/25862682/133466878-be4ac7a9-dde4-4c28-bed0-862681ca1ff8.PNG" width="32%" />
  <img src="https://user-images.githubusercontent.com/25862682/126900264-726e5878-a1e0-4f38-b64a-9e9d76bf3206.PNG" width="32%" />
  <img src="https://user-images.githubusercontent.com/25862682/126900258-37a988f7-1cf9-4273-a069-1c2714ac134c.PNG" width="32%" />
  <img src="https://user-images.githubusercontent.com/25862682/133466845-2c65b772-485b-483e-8e30-f0d36c292510.PNG" width="32%" />
  <img src="https://user-images.githubusercontent.com/25862682/133466841-047bef9a-b39f-4951-a9a6-6be14f8a7c35.PNG" width="32%" />
  <img src="https://user-images.githubusercontent.com/25862682/133466833-c81aac7b-18f7-4238-8123-7f8445287563.PNG" width="32%" />
  <img src="https://user-images.githubusercontent.com/25862682/133466824-47c28c8f-bcb3-4543-8a9e-c038ac66b13b.PNG" width="32%" />
  <img src="https://user-images.githubusercontent.com/25862682/126900266-4405a84b-e119-433f-be78-4ca37691fd8c.PNG"/>
</p>

## Build the Project

1. Install Xcode and Rust toolchains. Make sure you have set your command line tools location correctly by

   安装 Xcode 及 Rust 相关工具链。

   ```bash
   $ sudo xcode-select --switch /Applications/Xcode.app
   ```

2. Install other prerequisites.

   安装其他依赖。

   ```bash
   $ brew install swift-protobuf
   $ cargo install cargo-lipo
   $ rustup target add aarch64-apple-ios
   $ rustup target add x86_64-apple-ios  # Intel Macs only
   ```

3. Clone the repository and run at the project root:

   克隆仓库到本地，在项目的根目录，运行

   ```bash
   $ cargo install cargo-lipo
   $ make release
   ```

   You'll find a `.a` archive and its header under `out/`

   检查 `out` 目录，将会生成一个 `.a` 库和其对应的 `.h` 头文件

4. Open the Xcode project `app/NGA.xcodeproj`. Run the app after you set the correct Apple ID.

打开 Xcode 工程 `app/NGA.xcodeproj`，重新设置签名 Apple ID 后，编译运行

## Statements

- 本项目中涉及的 NGA 等文字，NGA 版块、帖子、用户等数据，AC 娘表情等资源，其版权均归 NGA BBS (https://ngabbs.com) 所有。
- This project _currently_ has NO LICENSE. You MAY NOT modify or redistribute this code without explicit permission.
