---
name: duo-hinge
description: Fold and unfold the iPhone Duo simulator from the command line, without Device Hub or any human step. Use when testing MNGA on the inner display, checking how layouts react to folding, or whenever a task needs the Duo simulator in a specific pose.
---

# Duo Hinge

Neither `simctl`, `devicectl`, nor XCTest can fold the iPhone Duo simulator. `scripts/duo-hinge` runs a small helper inside the simulator that posts the same HID event as Device Hub's hinge slider, then confirms the angle through CoreMotion. Device Hub does not need to be running, and no Accessibility permission is needed.

## Usage

```bash
.agents/skills/duo-hinge/scripts/duo-hinge open    # 180 degrees, inner display
.agents/skills/duo-hinge/scripts/duo-hinge close   # 0 degrees, outer display
.agents/skills/duo-hinge/scripts/duo-hinge half    # 90 degrees
.agents/skills/duo-hinge/scripts/duo-hinge set 127 # any angle from 0 to 180
.agents/skills/duo-hinge/scripts/duo-hinge get     # current angle
.agents/skills/duo-hinge/scripts/duo-hinge status  # angle, displays, and orientation
```

Run it outside the Bash sandbox, because `simctl` cannot reach CoreSimulator from inside it. Set `DUO_HINGE_DEVICE` to a UDID when several iPhone Duo simulators are booted.

`open` and `close` land exactly on 180 and 0 degrees. An angle in between settles up to about 5 degrees away, on a side that depends on the direction of travel, so 127 settled at 125.1 going up and 129.7 going down. `set` returns on the first reading within 6 degrees, which can come before the hinge settles, so run `get` afterwards when the exact angle matters.

## Testing after a pose change

- The iOS Simulator `control` tool follows the active display for screenshots and taps. Take a new screenshot after each pose change, because the point size changes: 466x678 on the outer display and 951x669 on the inner display.
- `xcrun simctl io <udid> screenshot --display=primary` captures the outer display, and `--display=primary-1` captures the inner one. `--display=internal` fails with `Invalid argument`.
- Only an app built with the iOS 27 SDK or later resizes. An older build stays in a small centered area on the inner display, so check `DTSDKName` in the app's `Info.plist` before judging a layout.

## When it breaks

The helper relies on private interfaces, so a new Xcode or runtime can break it. A failed `set` exits non-zero after 3 seconds. If the simulator stops responding to hinge events, shut it down and boot it again. [artemnovichkov/hinge](https://github.com/artemnovichkov/hinge) tracks the same mechanism and is the first place to compare against.
