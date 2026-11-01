# Checked Pointer Arithmetic

Checked pointer arithmetic makes hardware supporting the `FEAT_CPA2` extension detect when a pointer computation overflows out of the address bits into the upper bits of the pointer. Those upper bits hold the Memory Tagging Extension (MTE) tag, when such protection is enabled. Overflowing into them is what lets arithmetic walk from one object into another while still presenting a tag the hardware accepts — without this check, that overflow is how an attacker would defeat tagging.

Detection happens in two places: explicit arithmetic poisons its result, and every load and store checks the addition it performs as part of its addressing mode.

The dependency runs one way: checked pointer arithmetic needs hardware memory tagging enabled on the same target for its run time enforcement, while memory tagging works on its own. Checked pointer arithmetic also requires its own entitlement and the `arm64e.x1` slice.

> **Apple developer documentation:** entitlement reference for [`com.apple.security.hardened-process.checked-allocations.enforce-checked-pointer-arithmetic-overflow`](doc://com.apple.documentation/documentation/BundleResources/Entitlements/com.apple.security.hardened-process.checked-allocations.enforce-checked-pointer-arithmetic-overflow), and [Enabling Enhanced Security for your app](doc://com.apple.documentation/documentation/Xcode/enabling-enhanced-security-for-your-app) for the capability that provisions it. See `hardware-memory-tagging.md` for the memory-tagging protection this one defends.

## What It Does

Checked pointer arithmetic requires the **`arm64e.x1`** slice (Mach-O cpusubtype 12, `CPU_SUBTYPE_ARM64E_X1`) to be built, and that slice is where the compiler emits checked pointer arithmetic instructions: explicit pointer arithmetic becomes `ADDPT` / `SUBPT` / `MADDPT` / `MSUBPT` instead of `ADD` / `SUB`.

Those instructions are evaluated for overflow only when the application has the entitlements that enforce checked pointer arithmetic and runs on capable hardware. The same evaluation covers every load and store that computes its effective address by addition, whatever the addressing mode. For example, immediate-offset forms such as `LDR [Xn, #imm]`, or scaled register-offset forms such as `LDR [Xn, Xm, LSL #3]`.

The check compares the result's top byte, bits [63:56], against the **base operand's** top byte. That byte carries the 4-bit Memory Tagging Extension (MTE) tag in bits [59:56] when MTE is enabled. When the two differ, the arithmetic has overflowed into the top byte and the result is **poisoned**: bits [63:55] are copied from the base and bit [54] is set to the inverse of bit [55].

A poisoned pointer is deliberately non-canonical, so the next dereference takes a level-0 translation fault, delivered as `EXC_ARM_CPA_FAIL` (`0x108`) with ESR `0x92000004` (read) or `0x92000044` (write). A poisoned value used as a length or an offset instead of an address may present as `EXC_ARM_MTE_TAGCHECK_FAIL` instead. Poison also survives further arithmetic, so a poisoned value that is passed around and used later still faults at the point of use rather than being silently laundered.

Requiring the result's top byte to equal the base's is what confines pointer arithmetic to a single tagged region when tagging is enabled: a neighbouring allocation carries a different tag, so walking into it poisons the result instead of letting the access through.

## What Memory-safety Issues It Mitigates

- **Out-of-bounds access through an oversized or attacker-influenced offset** — with tagging enabled, an index or length large enough to leave the allocation changes the tag, so the derived pointer faults instead of reading or writing a neighbour
- **Tag forging against hardware memory tagging** — arithmetic can no longer be used to manufacture a pointer whose tag matches a different allocation, closing the bypass that would otherwise weaken MTE
- **Cross-allocation pointer deltas** — a difference between pointers into two different allocations (the classic post-`realloc` rebase of internal object pointers) carries non-zero high bytes, and adding it to a base is caught
- **Pointer/integer type confusion in arithmetic** — expressions that put an integer in the pointer position, or subtract a pointer stored as `uintptr_t`, produce a tag mismatch and fault at once
- **Dereference of a NULL or corrupted base** — a negative immediate offset applied to a NULL base pointer wraps the top byte from `0x00` to `0xFF` and is caught at the faulting instruction

These are ordinary memory-safety and correctness bugs, most of them undefined behaviour that the hardware turns into an immediate, localized fault instead of a silent corruption exploitable later.

## How to Enable

Four things must be enabled on an app target. Miss one and there is no protection.

| # | Set | Where | Xcode UI | Gives you |
|---|---|---|---|---|
| 1 | `ENABLE_HARDWARE_CHECKED_POINTER_ARITHMETIC_SLICE = YES` | build setting on the project or the target (`project.pbxproj` or an `.xcconfig`) | Build Settings > Security > "Enable Hardware-Checked Pointer Arithmetic Slice" | the `arm64e.x1` slice, which carries the checked instructions but is not enough for run time enforcement |
| 2 | `com.apple.security.hardened-process = <true/>` | the target's `.entitlements` file | Signing & Capabilities > + Capability > Enhanced Security | the Enhanced Security entitlement, which run time enforcement requires |
| 3 | `com.apple.security.hardened-process.checked-allocations = <true/>` | the target's `.entitlements` file | Signing & Capabilities > Enhanced Security > Memory Safety > "Enable Hardware Memory Tagging" | hardware memory tagging, which run time enforcement requires |
| 4 | `com.apple.security.hardened-process.checked-allocations.enforce-checked-pointer-arithmetic-overflow = <true/>` | the target's `.entitlements` file | Signing & Capabilities > Enhanced Security > Memory Safety > "Enforce Checking for Overflow of Pointer Arithmetic" | run time enforcement entitlement |

Row 4 is a sub-option of row 3, and row 3 of row 2. Row 2 also needs `com.apple.security.hardened-process.enhanced-security-version-string = 2`; Xcode writes that key when you add the capability, so write it yourself if you edit the entitlements file directly. See `enhanced-security.md` for the rest of that capability.

Hardware memory tagging is **required** for run time enforcement, which is why row 3 is in the table: the checked-pointer-arithmetic entitlement is a sub-option of `checked-allocations` and is not honoured without it. The two protections also reinforce each other — tagging is what gives the top byte a value worth comparing, and checked arithmetic in turn closes the tag-forging bypass against tagging.

Library and framework targets take row 1 only. Entitlements are granted per process from the main executable, so a library builds the slice but it is the consuming app's entitlements that decide whether checked pointer arithmetic is enforced.

`ENABLE_POINTER_AUTHENTICATION = YES` is recommended alongside row 1, though not strictly required for checked pointer arithmetic. The recommendation runs the other way too: once a target builds the `arm64e` slice, build the `arm64e.x1` slice as well and enable run time enforcement of checked pointer arithmetic on top of it.

Xcode warns at build time if row 4 is set while the target is not building `arm64e.x1`. Full enforcement requires the `arm64e.x1` slice and the entitlements. The warning is the only signal that the configuration is incomplete.

### What the build setting does

The `ENABLE_HARDWARE_CHECKED_POINTER_ARITHMETIC_SLICE` build setting appends `arm64e.x1` to `ARCHS_STANDARD`. That slice is a pre-requisite for run time enforcement of checked pointer arithmetic. The setting has no effect if `ARCHS` is overridden to something not based on `ARCHS_STANDARD`.

Measured on an iOS target:

| `ENABLE_POINTER_AUTHENTICATION` | `ENABLE_HARDWARE_CHECKED_POINTER_ARITHMETIC_SLICE` | Resulting `ARCHS_STANDARD` |
|---|---|---|
| NO | NO | `arm64` |
| YES | NO | `arm64 arm64e` |
| NO | YES | `arm64 arm64e.x1` |
| YES | YES | `arm64 arm64e arm64e.x1` |

Use the combination in the last row. With the slice enabled but pointer authentication off, the binary ships no `arm64e` slice, so devices without `FEAT_CPA2` fall back to `arm64` and lose pointer authentication on capable hardware. With both enabled, every device is covered: `arm64e.x1` where the hardware supports it, `arm64e` everywhere else where pointer authentication is supported.

Xcode's Validate Settings offers this setting as an upgrade task, "Enable Hardware Checked Pointer Arithmetic".

### Verifying the slice

Use `lipo -archs`:

```bash
lipo -archs MyApp.app/MyApp        # expect: arm64 arm64e arm64e.x1
```

## Code Changes Required

Generally none. The compiler emits the checked instructions in the `arm64e.x1` slice, and the hardware enforces them once the entitlements in "How to Enable" are in place.

Two kinds of code base do need changes, though. Code that relies on undefined behaviour in pointer arithmetic — a difference between pointers into two different allocations, an offset carried past the end of an object, arithmetic on a NULL base — has to be corrected, because that is precisely what the check detects. Less commonly, code that mixes pointer and integer types in one expression may need changes too: subtracting a pointer stored as `uintptr_t`, or putting an integer in the position where the compiler expects the base pointer, produces checked arithmetic on operands that were never meant to be an address and a displacement.

Expect the fault to be far from the poisoning: the instruction that poisons a value and the one that dereferences it may be in different functions, files, or libraries, with the value sitting in a struct field or global in between.

`__arm64e_x1__` is a predefined macro, for code that must be compiled differently for the `arm64e.x1` slice.

## How to Disable

| # | Set | Where | Xcode UI | Takes away |
|---|---|---|---|---|
| 1 | `ENABLE_HARDWARE_CHECKED_POINTER_ARITHMETIC_SLICE = NO` | build setting on the project or the target (`project.pbxproj` or an `.xcconfig`) | Build Settings > Security > "Enable Hardware-Checked Pointer Arithmetic Slice" | the `arm64e.x1` slice |
| 4 | remove `com.apple.security.hardened-process.checked-allocations.enforce-checked-pointer-arithmetic-overflow` | the target's `.entitlements` file | Signing & Capabilities > Enhanced Security > Memory Safety > uncheck "Enforce Checking for Overflow of Pointer Arithmetic" | enforcement at run time |

The row numbers in this table come from the table in "How to Enable".

To disable run time enforcement of checked pointer arithmetic in an app target, only the entitlement removal (row 4) is required. Whether or not the `arm64e.x1` slice should be removed (row 1) depends on evaluating its benefits beyond checked pointer arithmetic. Read `pointer-authentication.md` for more information.

If the only reason for building the `arm64e.x1` slice was to enable run time enforcement of checked pointer arithmetic by adding its entitlement to the app target, the recommendation is to undo both rows. Removing the slice only leaves an entitlement Xcode warns about.

A library or framework target has only row 1 to undo, since it never took the entitlement. Removing the `arm64e.x1` slice leaves the library without checked pointer arithmetic instructions. However, if the library still builds the `arm64e` slice and is loaded by an application enforcing checked pointer arithmetic at run time (i.e., an app that meets the criteria in section "How to Enable" and runs on capable hardware), load/store instructions in the library will still be checked.

Leave `com.apple.security.hardened-process` — row 2 in "How to Enable" — in place. It is the Enhanced Security capability itself, and clearing it disables far more than checked pointer arithmetic.

## Platform Availability

- **Platforms:** checked pointer arithmetic requires **iOS on a device with an A20 Pro chip or later** or **watchOS on a device with an S11 chip or later**. Both chips support `FEAT_CPA2`, which the `arm64e.x1` slice targets.
- **Simulator:** no action required. Simulator SDKs define no `arm64e.x1` architecture, so the build system drops it from a simulator build's effective architectures exactly as it does `arm64e`.

## Performance and Stability Impact

- **Performance:** low overhead — the check is part of the arithmetic and address generation the CPU already performs, with no extra instructions. The cost is binary size: a third slice.
- **Stability:** code with latent pointer-arithmetic bugs **will crash**, and undefined behaviour that has been benign for years is exactly what this catches. Expect faults in raw-pointer-heavy C/C++, in code that stores pointers as `uintptr_t`, and in code that rebases internal pointers in an object after a reallocation.
- **Adoption path:** enable pointer authentication and hardware memory tagging first. `arm64e.x1` is a pointer-authentication slice, so the target should already be building and shipping `arm64e` cleanly before a third slice is added, and tagging is what run time enforcement requires. Then build the `arm64e.x1` slice and add the enforcement entitlement, run your test suite and internal builds on hardware that implements `FEAT_CPA2`, and diagnose and fix each fault. An app ships with the entitlement enabled; a library or framework ships the slice alone, and the consuming app's entitlement is what enforces the checks. Checked pointer arithmetic has no soft mode: there is no setting that reports a fault without terminating the app, and hardware memory tagging's `soft-mode` sub-option does not cover these faults — it applies to tag-check failures, while a poisoned-pointer dereference is a translation fault. Plan for crashes during validation and fix them before shipping.
