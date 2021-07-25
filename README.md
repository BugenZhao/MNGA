# NGA App

[![Logic](https://github.com/BugenZhao/NGA/actions/workflows/logic.yaml/badge.svg)](https://github.com/BugenZhao/NGA/actions/workflows/logic.yaml)

An NGA App in SwiftUI with cross-platform logic in Rust.

## Features

- Built with pure SwiftUI which provides awesome UX feelings
- High-performance logic layer energized by Rust (and can be ported to other platforms with ease, check [Android Examples](android/README.md))

## Screenshots

<p align="middle">
  <img src="https://user-images.githubusercontent.com/25862682/126900256-1a8d23de-805f-498e-960f-be3d2304146b.PNG" width="32%" />
  <img src="https://user-images.githubusercontent.com/25862682/126900260-55949320-f6a9-4cab-a098-cc02edefdc1f.PNG" width="32%" />
  <img src="https://user-images.githubusercontent.com/25862682/126900261-43c08a26-49f6-4bb1-abc3-a536845193a1.PNG" width="32%" />
  <img src="https://user-images.githubusercontent.com/25862682/126900264-726e5878-a1e0-4f38-b64a-9e9d76bf3206.PNG" width="32%" />
  <img src="https://user-images.githubusercontent.com/25862682/126900258-37a988f7-1cf9-4273-a069-1c2714ac134c.PNG" width="32%" />
  <img src="https://user-images.githubusercontent.com/25862682/126900262-b8bf59d2-d567-43e5-8a68-6148370da3fd.PNG" width="32%" />
  <img src="https://user-images.githubusercontent.com/25862682/126900254-de643a1d-5c5d-48fb-ab8e-178d01f55aec.PNG" width="32%" />
  <img src="https://user-images.githubusercontent.com/25862682/126900265-9a87b7c3-858d-403c-b0d6-38e3e18f4741.PNG" width="32%" />
  <img src="https://user-images.githubusercontent.com/25862682/126900426-e89c314e-e4ec-4746-b014-f521e1547a03.PNG" width="32%" />
  <img src="https://user-images.githubusercontent.com/25862682/126900266-4405a84b-e119-433f-be78-4ca37691fd8c.PNG"/>
</p>

## Build the Project

1. 安装 Xcode 及 Rust 相关工具链
2. 安装 Swift 的 Protobuf 编译器
   ```bash
   $ brew install swift-protobuf
   ```
3. 克隆仓库到本地，在项目的根目录，运行

   ```bash
   $ make release
   ```

   检查 `out` 目录，将会生成一个 `.a` 库和其对应的 `.h` 头文件

4. 打开 Xcode 工程 `app/NGA.xcodeproj`，重新设置签名 Apple ID 后，编译运行

## Statements

- 本项目中涉及的 NGA 等文字，NGA 版块、帖子、用户等数据，AC 娘表情等资源，其版权均归 NGA BBS (https://ngabbs.com) 所有。
- This project _currently_ has NO LICENSE. You MAY NOT modify or redistribute this code without explicit permission.
