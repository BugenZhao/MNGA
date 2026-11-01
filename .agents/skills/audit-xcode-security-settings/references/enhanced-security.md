# Enhanced Security

Enhanced Security is an Xcode capability, not just a build setting. Enabling it fully touches **two places per target**:

1. Build settings (in pbxproj or xcconfig) — `ENABLE_ENHANCED_SECURITY` + pointer authentication.
2. Entitlements (in the target's `.entitlements` file) — the runtime-protection keys.

`ENABLE_ENHANCED_SECURITY = YES` is the build setting that turns on the compiler-driven pieces. The **Enhanced Security entitlements** (the `com.apple.security.hardened-process` key family) turn on the runtime-driven pieces and are what actually provisions the capability.

## Apple developer documentation

- [Enabling Enhanced Security for your app](doc://com.apple.documentation/documentation/Xcode/enabling-enhanced-security-for-your-app) — the canonical how-to.
- [Creating enhanced security helper extensions](doc://com.apple.documentation/documentation/Xcode/creating-enhanced-security-helper-extensions) — for XPC services / system extensions / driver extensions called from a hardened host.
- [Entitlements](doc://com.apple.documentation/documentation/BundleResources/Entitlements) — overview of every entitlement, including the `com.apple.security.hardened-process` family used below.

## Supported Product Types

Enhanced Security only applies on iOS, macOS, visionOS, and DriverKit, to these product types. Skip any target whose product type isn't in this list (frameworks, test bundles, app extensions other than those below, etc.) or whose platform isn't one of those four.

- `com.apple.product-type.application`
- `com.apple.product-type.application.on-demand-install-capable`
- `com.apple.product-type.xpc-service`
- `com.apple.product-type.driver-extension` (**build settings only** — entitlements do not apply to DriverKit)
- `com.apple.product-type.system-extension`
- `com.apple.product-type.tool`

## Libraries and Frameworks

Library and framework targets (frameworks, static frameworks, static libraries, dynamic libraries) are deliberately absent from the supported product-type list above — the Enhanced Security entitlements (the `com.apple.security.hardened-process` key family) apply only to executable targets that run directly on the OS, not to code linked into someone else's executable. The audit therefore skips entitlement edits on these targets.

The build settings cascaded by `ENABLE_ENHANCED_SECURITY = YES`, however, do still benefit library/framework targets — pointer authentication, security compiler warnings, typed allocator support, and C++ stdlib hardening all apply at compile time. **Enable pointer authentication on these targets** (`ENABLE_POINTER_AUTHENTICATION = YES`): the setting appends `arm64e` to the architecture list when `arm64` is present, so enabling it is exactly what produces the **universal `arm64`/`arm64e` binary** — consumers then pick the slice that matches their architecture. Do not skip pointer authentication on a library to avoid the larger artifact: the extra `arm64e` slice is the accepted tradeoff for control-flow integrity in shipped library code, and only one slice is loaded at runtime. See `universal-binaries-for-libraries.md` for the qualifying product types, the distribution check, and XCFramework guidance.

## Part A — Build Settings

One setting the audit needs to resolve to `YES` on every supported target:

- `ENABLE_ENHANCED_SECURITY = YES` — listed in the capability's `requiredValues`. Cascades automatically to pointer authentication, stack zero init, security compiler warnings, typed allocators, and C++ stdlib hardening (the audit does not manipulate these cascaded settings directly).

The apply path:

1. Set `ENABLE_ENHANCED_SECURITY = YES` at the project level so every target inherits it. If the project uses a project-level xcconfig, write it there. If the project is pbxproj-only, no MCP tool can write a project-level pbxproj setting — `SKILL.md` Phase 5 Step 1a guides the user through Xcode's Build Settings UI and then verifies via grep on `project.pbxproj`.
2. No simulator handling is required: the build system automatically drops `arm64e` from a simulator SDK's effective architectures (simulator SDKs define no `arm64e`), so simulator builds keep working with `arm64` and need no `ENABLE_POINTER_AUTHENTICATION = NO` override. Only override `ENABLE_POINTER_AUTHENTICATION = NO` (at the target level via `UpdateTargetBuildSetting` or the target's xcconfig) on a target that links a binary dependency not shipping `arm64e` — that dependency can't be linked as `arm64e` on any platform. See `pointer-authentication.md` for the platform / `arm64e` details. Skip if the target already has an explicit value — respect existing user intent.

A second build setting is relevant but outside the cascade: `ENABLE_HARDWARE_CHECKED_POINTER_ARITHMETIC_SLICE = YES` adds the `arm64e.x1` slice, which is a pre-requisite for run time enforcement of checked pointer arithmetic. It defaults to `NO`, is never set implicitly, and applies per target. See `checked-pointer-arithmetic.md`.

## Part B — Entitlements

All keys live in the target's `.entitlements` file. Each supported target has its own; the audit walks every one.

Required when the capability is enabled:

- [`com.apple.security.hardened-process`](doc://com.apple.documentation/documentation/BundleResources/Entitlements/com.apple.security.hardened-process) `= <true/>` — the main toggle. Without this, the runtime protections below are inert.
- [`com.apple.security.hardened-process.enhanced-security-version-string`](doc://com.apple.documentation/documentation/BundleResources/Entitlements/com.apple.security.hardened-process.enhanced-security-version-string) `= "2"` — selects v2 protections.

Default-ON sub-options (the audit adds these when missing):

- [`com.apple.security.hardened-process.hardened-heap`](doc://com.apple.documentation/documentation/BundleResources/Entitlements/com.apple.security.hardened-process.hardened-heap) — Memory Safety category. Adds extra type-isolation buckets to the allocator at runtime, regardless of compiler settings. Most effective in combination with the cascaded `CLANG_ENABLE_C_TYPED_ALLOCATOR_SUPPORT` / `CLANG_ENABLE_CPLUSPLUS_TYPED_ALLOCATOR_SUPPORT` build settings, which communicate type information from the compiler to the allocator.
- [`com.apple.security.hardened-process.dyld-ro`](doc://com.apple.documentation/documentation/BundleResources/Entitlements/com.apple.security.hardened-process.dyld-ro) — Runtime Protections. Marks dyld state read-only.
- [`com.apple.security.hardened-process.platform-restrictions-string`](doc://com.apple.documentation/documentation/BundleResources/Entitlements/com.apple.security.hardened-process.platform-restrictions-string) `= "2"` — Runtime Protections. Dyld + Mach messaging restrictions.

Default-OFF sub-options (audit reports state, does **not** auto-enable):

- [`com.apple.security.hardened-process.checked-allocations`](doc://com.apple.documentation/documentation/BundleResources/Entitlements/com.apple.security.hardened-process.checked-allocations) and its related keys — Hardware Memory Tagging (MTE). See `hardware-memory-tagging.md` for supported hardware. Recommend soft-mode rollout when reporting state.
- [`com.apple.security.hardened-process.checked-allocations.enforce-checked-pointer-arithmetic-overflow`](doc://com.apple.documentation/documentation/BundleResources/Entitlements/com.apple.security.hardened-process.checked-allocations.enforce-checked-pointer-arithmetic-overflow) — Checked Pointer Arithmetic (CPA2). Also needs the `arm64e.x1` slice from `ENABLE_HARDWARE_CHECKED_POINTER_ARITHMETIC_SLICE` for run time enforcement. See `checked-pointer-arithmetic.md`.

## Settings implied by Enhanced Security

These are automatically configured when `ENABLE_ENHANCED_SECURITY = YES` and do not need to be set explicitly:

- `GCC_WARN_SHADOW` — `-Wshadow`, detects variable declarations that shadow other variables.
- `CLANG_WARN_EMPTY_BODY` — `-Wempty-body`, detects empty bodies in control flow statements.
- `ENABLE_SECURITY_COMPILER_WARNINGS` — enables additional security-focused warnings (`-Wbuiltin-memcpy-chk-size`, `-Wformat-nonliteral`, `-Warray-bounds`, etc.). See `security-compiler-warnings.md`.
- `CLANG_CXX_STANDARD_LIBRARY_HARDENING` — set to `fast` in Release builds and `debug` in Debug builds (the cascade handles per-configuration differentiation automatically). This enables the hardened libc++ runtime checks only. It does NOT enable unsafe buffer usage warnings — that requires `ENABLE_CPLUSPLUS_BOUNDS_SAFE_BUFFERS` separately (see `cpp-hardening.md`).
- `CLANG_ENABLE_C_TYPED_ALLOCATOR_SUPPORT` — communicates type information from the compiler to the allocator for C code. Works in combination with the `hardened-heap` sub-option of Enhanced Security (see below).
- `CLANG_ENABLE_CPLUSPLUS_TYPED_ALLOCATOR_SUPPORT` — same, for C++ code.

## Settings NOT covered by Enhanced Security

These must be set independently and are out of scope for this reference:

- All `CLANG_ANALYZER_SECURITY_*` checkers
- Additional `CLANG_WARN_*` / `GCC_WARN_*` diagnostics not flipped by Enhanced Security (e.g. `CLANG_WARN_SUSPICIOUS_IMPLICIT_CONVERSION`, `GCC_WARN_ABOUT_RETURN_TYPE`)
- `GCC_TREAT_IMPLICIT_FUNCTION_DECLARATIONS_AS_ERRORS`, `CLANG_TIDY_*`
- `ENABLE_C_BOUNDS_SAFETY` / `ENABLE_CPLUSPLUS_BOUNDS_SAFE_BUFFERS` (defensive programming models, separate adoption)
