# MNGA Project Explained for Agents

## Project Structure

MNGA consists of two main components:

- **SwiftUI UI Module** - Handles user interface and interactions
- **Rust Business Module** - Handles core business logic, networking, and data processing

The two modules communicate via FFI using Protocol Buffers for data exchange.

## Rust Logic Module

This section covers the design and implementation of the Rust-based business module.

### Layout

- `logic/service`: Tokio-based crate that implements business services and exposes `dispatch_async`/`dispatch_sync` for the Swift bridge.
- `logic/protos`: Protobuf wrapper crate; `build.rs` regenerates Rust types in `logic/protos/src/generated` from shared `.proto` files.
- Supporting crates: `logic/text` (rich-text parsing), `logic/cache` (sled-backed cache), and `logic/config` (runtime configuration) are all consumed by `logic/service`.
- `logic/logic`: the `logic` crate that is compiled into the framework Swift links against; it owns the FFI surface and `bindings.h`.

### Proto Sources

- `protos/DataModel.proto` defines shared models such as `Topic`, `User`, `Post`, and enums used on both sides of the bridge.
- `protos/Service.proto` defines the `SyncRequest` and `AsyncRequest` oneofs plus every request/response pair that `logic/service` dispatches.
- Building `logic/protos` (e.g., via `cargo check -p service`, `make logic-sim`, or the iOS builds) reruns `logic/protos/build.rs` to update the generated Rust bindings; remember to run `make swift-pb` after proto edits so Swift stays in sync.

### Adding a Service

1. Extend `protos/Service.proto` (and `DataModel.proto` if new types are needed) with the request/response messages and place the new entry in either `SyncRequest.value` or `AsyncRequest.value`.
2. Regenerate protobuf bindings by rebuilding the Rust crate (`cargo check -p service` is enough) and re-run `make swift-pb` for Swift stubs.
3. Implement the business logic in `logic/service/src`, creating a new module if the functionality does not fit an existing one.
4. Register the handler:
   - Async services: add a `handle!(service_name, function_name);` line in `logic/service/src/dispatch/handlers_async.rs`.
   - Sync services: add a wrapper in `logic/service/src/dispatch/handlers_sync.rs` and match the new variant in `dispatch_sync` inside `logic/service/src/dispatch/mod.rs`.
5. If the service needs caching or shared state, reuse the helpers in `logic/cache`, `logic/text`, and `logic/service/src/utils.rs` to stay consistent with existing code.

#### References

Here are the references for NGA's interface specifications. The information might not be completely accurate or up-to-date, so compare different information sources before taking action.

- https://github.com/wolfcon/NGA-API-Documents/wiki
- https://gitee.com/AgMonk/nga-api-doc
- Android open-source client: https://github.com/Justwen/NGA-CLIENT-VER-OPEN-SOURCE

### Existing Services

Services under `logic/service/src`:

- `request.rs`: stores and mutates the global `RequestOption`, including base URL overrides and custom user agents.
- `auth.rs`: keeps the current `AuthInfo` in memory and exposes `set_auth`/`current_uid`.
- `cache.rs`: implements `CacheRequest` handling with prefix-based cache scans and clears.
- `clock_in.rs`: `clock_in` endpoint that memoizes daily sign-ins per user via the shared cache.
- `forum.rs`: forum discovery (`get_forum_list`), subforum subscription management (`set_subforum_filter`), and forum search.
- `topic.rs`: core topic workflows—forum topic lists, topic details, hot topics, favorites/folders, topic search, per-user topic feeds, and related extraction helpers.
- `post.rs`: post-level operations including vote tracking, reply flows (`post_reply`, `post_reply_fetch_content`), attachment uploads, hot replies/comments parsing, locating a post in its topic, and per-user post history.
- `history.rs`: stores topic snapshots in cache and serves `get_topic_history`.
- `msg.rs`: handles short message conversations (`get_short_msg_list`, `get_short_msg_details`, `post_short_msg`) and participant parsing.
- `noti.rs`: notification fetch (`fetch_notis`), normalization, caching, and synchronous `mark_noti_read`.
- `user.rs`: shared `UserController`, anonymous ID handling, and the `get_remote_user` service.
- `attachment.rs`: converts attachment nodes into `Attachment` models for post rendering.

## Development Workflow

### After updating Rust code

```bash
cargo fmt --all
cargo clippy --workspace --all-targets --all-features -- -D warnings
make logic-ios
```

The `cargo` commands match what CI enforces.
`make logic-ios` compiles a new logic framework for Swift to link against, if you're going to build the app.

### After updating .proto files

```bash
make swift-pb
```

Generates Swift protobuf code. Rust protobuf code is generated automatically during compilation.

### After making changes to Swift app code

```bash
make swiftformat
make build # xcraft will regenerate the Xcode project via Tuist if necessary
```

Updates the Xcode project file (if necessary, e.g., when adding new files, dependencies, etc.) and formats the Swift code. Build the app (for check purposes only) after making changes.

Remember to update localization file at `app/Shared/Localization/zh-Hans.lproj/Localizable.strings` after making changes to the UI, if applicable. No need to update English localization file, as you can directly use English string literals in the code.

## Common Commands

- `make logic-ios` - Build iOS framework
- `make swift-pb` - Generate Swift protobuf code
- `make logic-sim` - Build simulator-only version (faster for development)
- `make logic-deploy` - Build release version
- `make launch-sim` - Build the logic for the simulator only, then launch the app there

## Important Notes

- Avoid any Chinese in source code, including comments and string literals, unless it's a user-generated content in test data.
- Before changing navigation or the root layout, read `docs/navigation.md`, which records where every navigation lands and how to check for regressions. Keep it up to date.
- The UI is designed for iOS 26. Note that this is NOT a typo. Apple released iOS 26 in 2025. The minimum deployment target is iOS 18.4 (see `app/Project.swift`), so gate newer APIs with `if #available(iOS 26.0, *)`.
- APIs of SwiftUI is evolving very fast. Consult the `swiftui-specialist` and `swiftui-whats-new-27` skills, and always refer to the latest documentation.
- If you need real NGA data for testing, study the existing Rust API implementations under `logic/service/src` first (`topic.rs`, `post.rs`, `forum.rs`, etc.) to understand the NGA request/response shape, then send real requests following those implementations instead of inventing new endpoints or payloads. You may have to pass some auth info when making requests, see `logic/.env`; use them locally and do not expose or commit them.

## Agent Configuration

- Skills live in `.agents/skills/`. `.claude/skills` is a symlink to it because Claude Code only discovers skills from that path, so add new skills under `.agents/skills/`.
- Apple's skills come from Xcode. After an Xcode update, run `xcrun agent skills export --output-dir <tmp>` and refresh the ones kept here; the export may include skills this project deliberately omits.
- Keep this file to durable instructions that apply across tasks. Do not record individual decisions, fixes, or dated notes here; move reusable workflows into a skill and leave the rest to the code and git history.

## Pull Request

`main` is protected and rejects direct pushes, so always work on a branch and land changes through a PR. PRs are squash-merged, need the `Fastlane Build` and `Lint` checks to pass, and need all review threads resolved.

When you are asked to submit a PR, please make sure to:

- Follow the PR title convention by checking the history of commit messages in `main` branch.
- Provide a clear and concise description of the changes you made and the reason behind them.

## Running in the Simulator

Use your own iOS Simulator tooling for end-to-end testing and development of the app.

- `make launch-sim` is the fastest way to get a simulator build running.
- In MNGA, the accessibility tree is good enough for navigation and screen-state confirmation.
- Prefer deep links like `mnga://topic/<tid>` when a known topic must be opened quickly (see `Constants.MNGA` for the other routes). For testing purposes, you can use the well-known topic ID `45150945` to evaluate general functionality.
