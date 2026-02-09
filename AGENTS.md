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

### Proto Sources

- `protos/DataModel.proto` defines shared models such as `Topic`, `User`, `Post`, and enums used on both sides of the bridge.
- `protos/Service.proto` defines the `SyncRequest` and `AsyncRequest` oneofs plus every request/response pair that `logic/service` dispatches.
- Building `logic/protos` (e.g., via `cargo check -p logic-service`, `make logic-sim`, or the iOS builds) reruns `logic/protos/build.rs` to update the generated Rust bindings; remember to run `make swift-pb` after proto edits so Swift stays in sync.

### Adding a Service

1. Extend `protos/Service.proto` (and `DataModel.proto` if new types are needed) with the request/response messages and place the new entry in either `SyncRequest.value` or `AsyncRequest.value`.
2. Regenerate protobuf bindings by rebuilding the Rust crate (`cargo check -p logic-service` is enough) and re-run `make swift-pb` for Swift stubs.
3. Implement the business logic in `logic/service/src`, creating a new module if the functionality does not fit an existing one.
4. Register the handler:
   - Async services: add a `handle!(service_name, function_name);` line in `logic/service/src/dispatch/handlers_async.rs`.
   - Sync services: add a wrapper in `logic/service/src/dispatch/handlers_sync.rs` and match the new variant in `dispatch_sync` inside `logic/service/src/dispatch/mod.rs`.
5. If the service needs caching or shared state, reuse the helpers in `logic/cache`, `logic/text`, and `logic/service/src/utils.rs` to stay consistent with existing code.

### Existing Services

Services under `logic/service/src`:

- `request.rs`: stores and mutates the global `RequestOption`, including base URL overrides and custom user agents.
- `auth.rs`: keeps the current `AuthInfo` in memory and exposes `set_auth`/`current_uid`.
- `cache.rs`: implements `CacheRequest` handling with prefix-based cache scans and clears.
- `clock_in.rs`: `clock_in` endpoint that memoizes daily sign-ins per user via the shared cache.
- `forum.rs`: forum discovery (`get_forum_list`), subforum subscription management (`set_subforum_filter`), and forum search.
- `topic.rs`: core topic workflows—forum topic lists, topic details, hot topics, favorites/folders, topic search, per-user topic feeds, and related extraction helpers.
- `post.rs`: post-level operations including vote tracking, reply flows (`post_reply`, `post_reply_fetch_content`), attachment uploads, hot replies/comments parsing, and per-user post history.
- `history.rs`: stores topic snapshots in cache and serves `get_topic_history`.
- `msg.rs`: handles short message conversations (`get_short_msg_list`, `get_short_msg_details`, `post_short_msg`) and participant parsing.
- `noti.rs`: notification fetch (`fetch_notis`), normalization, caching, and synchronous `mark_noti_read`.
- `user.rs`: shared `UserController`, anonymous ID handling, and the `get_remote_user` service.
- `attachment.rs`: converts attachment nodes into `Attachment` models for post rendering.

## Development Workflow

### After updating Rust code

```bash
cargo clippy
make logic-ios
```

Run `cargo clippy` to check for potential issues.
Compiles a new logic framework for Swift to link against, if you're going to build the app.

### After updating .proto files

```bash
make swift-pb
```

Generates Swift protobuf code. Rust protobuf code is generated automatically during compilation.

### After making changes to Swift app code

```bash
make tuist
make swiftformat
make build
```

Updates the Xcode project file (if necessary, e.g., when adding new files, dependencies, etc.) and formats the Swift code. Build the app (for check purposes only) after making changes.

Remember to update localization file at `app/Shared/Localization/zh-Hans.lproj/Localizable.strings` after making changes to the UI, if applicable. No need to update English localization file, as you can directly use English string literals in the code.

## Common Commands

- `make logic-ios` - Build iOS framework
- `make swift-pb` - Generate Swift protobuf code
- `make logic-sim` - Build simulator-only version (faster for development)
- `make logic-deploy` - Build release version

## Important Notes

- Avoid any Chinese in source code, including comments and string literals.
- The project is targeting iOS 26. Note that this is NOT a typo. Apple released iOS 26 in 2025.
- APIs of SwiftUI is evolving very fast. Always refer to the latest documentation via `sosumi` MCP server.
