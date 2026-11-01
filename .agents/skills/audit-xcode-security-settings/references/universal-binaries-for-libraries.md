# Universal Binaries for Libraries

**Pointer authentication is highly recommended for library and framework targets.** Enabling it (`ENABLE_POINTER_AUTHENTICATION = YES`, directly or via the `ENABLE_ENHANCED_SECURITY` cascade) is by itself enough to produce a **universal binary**: the build system appends `arm64e` to `ARCHS_STANDARD` whenever `arm64` is already present, so the target builds **both** an `arm64` slice and an `arm64e` slice. This happens for any target — application or library — not just libraries; there is no setting that makes pointer authentication produce an `arm64e`-only build.

Once a distributed library is being built with pointer authentication, consider `ENABLE_HARDWARE_CHECKED_POINTER_ARITHMETIC_SLICE = YES` as well. It adds a third slice, so the target builds `arm64`, `arm64e`, and `arm64e.x1`. The `arm64e.x1` slice carries security protections over your code that the `arm64e` slice does not:

- **Checked pointer arithmetic** instructions, which are enforced at run time only if the consuming app's entitlements meet the requirements in `checked-pointer-arithmetic.md`. Entitlements do not apply to library and framework targets, so you ship the slice and the app must enable enforcement.
- **FPAC** — a failed pointer authentication faults at the authenticating instruction rather than later, when the pointer is used.
- **PAC with LR diversity** — a signed return address cannot be replayed at a different call site.

The slice exists for iOS and watchOS targets only. Test on hardware that supports it before shipping: as with `arm64e`, latent pointer bugs in library code surface as crashes in the consuming app. See `checked-pointer-arithmetic.md` and `pointer-authentication.md`.

For a library or framework you ship to other developers, a universal binary is exactly what you want: a Mach-O that contains `arm64`, `arm64e` and `arm64e.x1` slices. The dynamic linker (or `lipo` at the static-archive level) selects whichever slice matches the consumer's architecture, so the library author does not force an architecture choice on downstream projects — plain-`arm64` consumers keep working, and consumers who opt into arm64e get the pointer-authentication protections.

The one thing to verify is that the **distributed** build actually emits every slice. `ONLY_ACTIVE_ARCH = YES` (the conventional Debug value) builds only the active development architecture; a Release/distribution configuration uses `ONLY_ACTIVE_ARCH = NO`, so the full `ARCHS` list is built. Distribute the Release artifact (or set `ONLY_ACTIVE_ARCH = NO` for whatever configuration you ship) so every slice in `ARCHS` lands in the binary.

Warn when a library or framework target sets `ONLY_ACTIVE_ARCH = YES` in a Release/distribution configuration: only the active architecture gets built, which forces every consumer onto that single slice — rarely what the library author intends.

Do not skip pointer authentication on the grounds that multiple slices produce a larger binary. The on-disk artifact roughly doubles for two slices, but at runtime dyld loads only the slice matching the running CPU — RAM footprint, code-page residency, and execution cost are unchanged. The alternative (leaving pointer authentication off on the library) gives up control-flow-integrity protections — ROP/JOP mitigation, vtable / function-pointer hijack defense — for every consumer of that library, with no consumer-side knob that can recover them after the fact. Ship both slices.

> "Fat binary" / "fat archive" is the Mach-O-format term used by tools like `lipo` and `nm`. This is known as a **universal binary**.

## Qualifying Product Types

This document's guidance applies to any target whose product type is in this set:

- `com.apple.product-type.framework` (dynamic framework)
- `com.apple.product-type.framework.static` (static framework)
- `com.apple.product-type.library.static` (`.a` static library)
- `com.apple.product-type.library.dynamic` (`.dylib` dynamic library)

Application, XPC service, system extension, driver extension, and tool targets are out of scope for this document's extra packaging guidance. They already get the universal `arm64`+`arm64e` build from pointer authentication, and because they are not linked into anyone else's project there is no consumer-compatibility concern to manage — no special handling is needed.

## How to Check

Confirm every expected slice landed in the shipped artifact:

```bash
lipo -archs path/to/YourFramework.framework/YourFramework
# arm64 arm64e                 — with ENABLE_POINTER_AUTHENTICATION = YES
# arm64 arm64e arm64e.x1       — plus ENABLE_HARDWARE_CHECKED_POINTER_ARITHMETIC_SLICE = YES
```

## XCFramework Distribution

If you distribute via `.xcframework` (typical for binary Swift Package and CocoaPods deliveries), each per-platform slice inside the XCFramework should itself be a universal binary. Bundle them with `xcodebuild -create-xcframework -framework <ios-device-build> -framework <ios-sim-build> ...` as usual; the `-create-xcframework` step does not change architectures, it just packages already-built frameworks for multiple platforms. To ship the `arm64e.x1` slice as well, leave `ARCHS` unset and let `ENABLE_HARDWARE_CHECKED_POINTER_ARITHMETIC_SLICE = YES` append it.

Note that `arm64e` exists on every device platform (iOS device, macOS, visionOS device, DriverKit, tvOS device, watchOS device) but on no Simulator SDK. Simulator slices stay `arm64` (Apple Silicon Mac) plus `x86_64` (Intel Mac) — see `pointer-authentication.md` for the full platform table. `arm64e.x1` is narrower still: it exists for iOS and watchOS device builds only, so a framework built for several platforms carries that slice on some of them and not others.

## Related References

- `pointer-authentication.md` — what arm64e and pointer authentication actually do, and the consumer-side compatibility note for binary dependencies.
- `checked-pointer-arithmetic.md` — the checked pointer arithmetic protection that builds on the `arm64e.x1` slice.
- `enhanced-security.md` — how Enhanced Security build settings (including pointer authentication) cascade to library/framework targets even though entitlements do not apply to them.
