# Running System Shortcuts
**SDK Version:** iOS 27.0 and later

If the user's deployment target is below iOS 27, the APIs in this reference (`SystemShortcut` and `RunSystemShortcutIntent`) require availability gating. Both types are iOS-only — they are `@available(macOS, unavailable)`, `@available(tvOS, unavailable)`, `@available(watchOS, unavailable)`, and `@available(visionOS, unavailable)` — so any use also needs a fallback on non-iOS targets.
iOS 27 adds a way to run a system-provided shortcut from an interactive widget. `RunSystemShortcutIntent` is a `SystemIntent` that runs a `SystemShortcut`, and its only supported use is to back a SwiftUI `Button(intent:)` inside a widget configuration. In the running example, a "TravelTracking" widget exposes a button that runs a system shortcut. Outside a widget button, `RunSystemShortcutIntent` has no functionality — do not surface it as an App Shortcut, invoke it from `perform()`, or wire it anywhere else.

## SystemShortcut

`SystemShortcut` is an opaque value that identifies a system-provided shortcut. It conforms to `Equatable` and `Sendable`. It exposes no public initializer and no public static factory in the SDK, so app code cannot construct or enumerate `SystemShortcut` values directly — treat any specific value as system-resolved. Because of this, a `SystemShortcut` is only ever something you receive from a system-provided context and pass straight through; do not store your own or model it as a custom property on a widget timeline entry.

```swift
// A SystemShortcut you were handed by a system-provided context.
// You compare or pass it through — you never construct it yourself.
@available(iOS 27.0, *)
func makeRunIntent(for shortcut: SystemShortcut) -> RunSystemShortcutIntent {
    RunSystemShortcutIntent(shortcut: shortcut)
}
```

**Availability:** iOS 27.0. Unavailable on macOS, tvOS, watchOS, and visionOS.

## RunSystemShortcutIntent

`RunSystemShortcutIntent` is a `SystemIntent` that runs a system shortcut. It has two initializers: the parameterless `init()`, and `init(shortcut:)` which takes a system-resolved `SystemShortcut`. Use it only to back a SwiftUI `Button(intent:)` inside a widget configuration; it has no functionality in any other context.

```swift
// In a WidgetKit view body for a "TravelTracking" widget configuration.
// `entry.configuration.shortcut` is a SystemShortcut carried on the widget's
// configuration entry (a value the system resolved — not one the app built).
@available(iOS 27.0, *)
private var runShortcutButton: some View {
    Button(intent: RunSystemShortcutIntent(shortcut: entry.configuration.shortcut)) {
        Label("Run Shortcut", systemImage: "bolt")
    }
}
```

If you do not have a specific `SystemShortcut` in hand, use the parameterless initializer and let the system resolve which shortcut runs:

```swift
@available(iOS 27.0, *)
private var runShortcutButton: some View {
    Button(intent: RunSystemShortcutIntent()) {
        Label("Run Shortcut", systemImage: "bolt")
    }
}
```

**Availability:** iOS 27.0. Unavailable on macOS, tvOS, watchOS, and visionOS.
