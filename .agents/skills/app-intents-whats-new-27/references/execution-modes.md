# Execution Modes, Foreground Continuation & Long-Running Intents
**SDK Version:** iOS 26.0 and later

If the user's deployment target is below iOS 26 / macOS 26 / watchOS 26 / tvOS 26 / visionOS 26, the new APIs in this reference (`supportedModes` / `IntentModes`, `continueInForeground(_:alwaysConfirm:)`, `needsToContinueInForegroundError(_:alwaysConfirm:)`, `UndoableIntent`) require availability gating; `CancellableIntent` / `IntentCancellationReason` are iOS 26.4 and later, and `LongRunningIntent` / `performBackgroundTask(options:operation:)` / `LongRunningTaskOptions` / `IntentExecutionTargets` / `allowedExecutionTargets` are iOS 27.0 and later.

iOS 26 replaces the boolean `openAppWhenRun` flag with a declarative `IntentModes` option set, so an intent states where it runs (background, foreground, or a runtime-decided mix) and only escalates to the foreground when its code actually asks. The same releases add first-class cancellation and undo, and iOS 27 adds system-managed background execution that can outlive the caller plus control over which process runs the intent. The examples use the WWDC TravelTracking sample, with `LandmarkEntity`, `GetCrowdStatusIntent`, and `TagPhotosIntent`.

## Supported modes

`supportedModes: IntentModes` declares where an intent runs. Use `.background` for headless work; `.foreground` (equivalent to `.foreground(.immediate)`) to switch to the app **before** `perform()` runs; or `.foreground(_:)` with a `ForegroundMode` — `.immediate` (switch before `perform()` runs), `.deferred` (start work first, switch when content is ready), or `.dynamic` (decide at runtime). `IntentModes` is an `OptionSet`, so combine them: `[.background, .foreground(.dynamic)]` starts in the background and escalates on demand. Omitting the property defaults to `.background` for a plain intent — the system derives the default (a legacy `openAppWhenRun = true` maps to `.foreground`; a URL-representable `OpenIntent` maps to `.background`). The old `static var openAppWhenRun: Bool` is deprecated in 26.0; declare `supportedModes` and delete the flag.

```swift
@available(iOS 26.0, *)
struct TagPhotosIntent: AppIntent {
    static let title: LocalizedStringResource = "Tag Photos"
    // Try to tag headlessly; escalate to the app only when needed.
    static var supportedModes: IntentModes { [.background, .foreground(.dynamic)] }

    func perform() async throws -> some IntentResult {
        // ...
        return .result()
    }
}
```

**Availability:** iOS 26.0, macOS 26.0, watchOS 26.0, tvOS 26.0, visionOS 26.0.

## Foreground continuation

An intent declared `[.background, .foreground(.dynamic)]` starts in the background and can pull itself into the foreground only when it needs to. Call `continueInForeground(_:alwaysConfirm:)` to escalate inline and keep running after the switch, or `throw needsToContinueInForegroundError(_:alwaysConfirm:)` when the intent cannot proceed at all without the app and you want the system to prompt. Pass `alwaysConfirm: false` to skip the confirmation dialog when the surface already implies intent. Some contexts (voice-only, certain widgets) cannot bring the app forward, so guard on `systemContext.currentMode.canContinueInForeground` first; calling `continueInForeground` in a context that cannot foreground throws.

```swift
@available(iOS 26.0, *)
struct GetCrowdStatusIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Crowd Status"
    static var supportedModes: IntentModes { [.background, .foreground(.dynamic)] }

    @Parameter var landmark: LandmarkEntity

    func perform() async throws -> some IntentResult {
        guard try await needsFullEditor(for: landmark) else {
            return .result()   // finished in the background, never touched UI
        }
        guard systemContext.currentMode.canContinueInForeground else {
            throw needsToContinueInForegroundError("Open \(landmark.name) to review crowd status")
        }
        try await continueInForeground("Continue in the app?", alwaysConfirm: false)
        await presentCrowdStatus(for: landmark)   // now foreground — safe to present UI
        return .result()
    }
}
```

**Availability:** iOS 26.0, macOS 26.0, watchOS 26.0, tvOS 26.0, visionOS 26.0. (`systemContext.currentMode` and `IntentModes.Current.canContinueInForeground` share the same availability.)

## Undoable intents

`UndoableIntent` refines `SystemIntent` and exposes a `@MainActor` `undoManager: UndoManager?`. Register an undo action against it so the system can offer Undo for the intent's effect. Because `undoManager` is `@MainActor`, touch it only from a main-actor context — mark `perform()` `@MainActor` or hop explicitly.

```swift
@available(iOS 26.0, *)
struct DeleteLandmarkIntent: AppIntent, UndoableIntent {
    static let title: LocalizedStringResource = "Delete Landmark"
    @Parameter var landmark: LandmarkEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        let snapshot = try await ModelData.shared.delete(landmark)
        undoManager?.registerUndo(withTarget: ModelData.shared) { $0.restore(snapshot) }
        return .result()
    }
}
```

**Availability:** iOS 26.0, macOS 26.0, watchOS 26.0, tvOS 26.0, visionOS 26.0.

## Cancellable intents

`CancellableIntent` lets an intent observe cancellation with a reason. Wrap the cancellable work in `withIntentCancellationHandler(operation:onCancel:)`; the `onCancel` handler receives an `IntentCancellationReason`, which is either `.timeout` or `.userCancelled`, so you can distinguish a system timeout from an explicit user cancel.

```swift
@available(iOS 26.4, *)
struct GetCrowdStatusIntent: AppIntent, CancellableIntent {
    static let title: LocalizedStringResource = "Get Crowd Status"
    @Parameter var landmark: LandmarkEntity

    func perform() async throws -> some IntentResult {
        try await withIntentCancellationHandler {
            try await ModelData.shared.fetchCrowdStatus(for: landmark)
        } onCancel: { reason in
            ModelData.shared.stopFetch(dueTo: reason)   // .timeout or .userCancelled
        }
        return .result()
    }
}
```

**Availability:** iOS 26.4, macOS 26.4, watchOS 26.4, tvOS 26.4, visionOS 26.4.

## Long-running intents

On iOS, iPadOS, watchOS, tvOS, and visionOS a background App Intent gets only about 30 seconds to finish before the system ends it (macOS has no such limit). So before iOS 27, work that ran longer than that risked being terminated when the window closed or the initiating surface went away. `LongRunningIntent` hands the work to a system-managed background task (BGContinuedProcessingTask) via `performBackgroundTask(options:operation:)`, which extends runtime past that limit and survives the initiating surface disappearing.

`LongRunningIntent` refines `ProgressReportingIntent`, so a Foundation `progress` object drives determinate progress, and the system's Live Activity displays that progress automatically with no presentation code of your own: `progress.localizedDescription` / `localizedAdditionalDescription` become the title and subtitle, and `completedUnitCount` / `totalUnitCount` drive the progress bar. Pass `options: .requiresGPU` (a `LongRunningTaskOptions` value) to tell the system the task needs GPU resources so it schedules accordingly. A second overload, `performBackgroundTask(options:operation:onCancel:)`, is available only when the intent also conforms to `CancellableIntent`, and its `onCancel` closure receives an `IntentCancellationReason`.

```swift
@available(iOS 27.0, *)
struct TagPhotosIntent: AppIntent, LongRunningIntent, CancellableIntent {
    static let title: LocalizedStringResource = "Tag Photos"
    static var supportedModes: IntentModes { .background }

    func perform() async throws -> some IntentResult {
        // The system observes self.progress via KVO and mirrors it to the Live Activity.
        progress.localizedDescription = "Tagging photos…"   // becomes the Live Activity title
        let tagged = try await performBackgroundTask(options: .requiresGPU) {
            try await ModelData.shared.tagPhotos { done, total in
                self.progress.totalUnitCount = Int64(total)
                self.progress.completedUnitCount = Int64(done)  // drives the progress bar
            }
        } onCancel: { reason in
            ModelData.shared.abortTagging(reason: reason)   // .timeout or .userCancelled
        }
        return .result(dialog: "Tagged \(tagged) photos")
    }
}
```

**Availability:** iOS 27.0, macOS 27.0, watchOS 27.0, tvOS 27.0, visionOS 27.0. (`LongRunningTaskOptions.requiresGPU` and the `onCancel:` overload share the same availability; the `onCancel:` overload additionally requires `Self: CancellableIntent`, iOS 26.4.)

## Execution targets

`allowedExecutionTargets: IntentExecutionTargets` pins which process runs an intent. `IntentExecutionTargets` is an `OptionSet` with `.default` (the system chooses — the default value), `.main` (the main app, for in-memory caches or live navigator state), `.appIntentsExtension` (the App Intents extension), and `.widgetKitExtension` (the WidgetKit extension, for latency-sensitive widget-driven runs). Prefer `.default` unless the code genuinely needs a specific process, since forcing `.main` defeats extension-based execution and adds launch latency.

```swift
@available(iOS 27.0, *)
struct AdvanceNavigationIntent: AppIntent {
    static let title: LocalizedStringResource = "Advance Navigation"
    static var supportedModes: IntentModes { .background }
    // Needs the main app's live navigator singleton.
    static var allowedExecutionTargets: IntentExecutionTargets { .main }

    @Parameter var meters: Double

    func perform() async throws -> some IntentResult {
        Navigator.shared.advance(by: meters)   // only valid in the main process
        return .result()
    }
}
```

**Availability:** iOS 27.0, macOS 27.0, watchOS 27.0, tvOS 27.0, visionOS 27.0.

## Availability summary

| API | iOS | macOS | watchOS | tvOS | visionOS |
|---|---|---|---|---|---|
| `supportedModes` / `IntentModes` (`.background`, `.foreground`, `.foreground(.immediate/.deferred/.dynamic)`) | 26.0 | 26.0 | 26.0 | 26.0 | 26.0 |
| `continueInForeground(_:alwaysConfirm:)` / `needsToContinueInForegroundError(_:alwaysConfirm:)` | 26.0 | 26.0 | 26.0 | 26.0 | 26.0 |
| `systemContext.currentMode.canContinueInForeground` | 26.0 | 26.0 | 26.0 | 26.0 | 26.0 |
| `UndoableIntent` (`@MainActor undoManager`) | 26.0 | 26.0 | 26.0 | 26.0 | 26.0 |
| `CancellableIntent` / `IntentCancellationReason` / `withIntentCancellationHandler` | 26.4 | 26.4 | 26.4 | 26.4 | 26.4 |
| `LongRunningIntent` / `performBackgroundTask(options:operation:)` / `LongRunningTaskOptions` | 27.0 | 27.0 | 27.0 | 27.0 | 27.0 |
| `IntentExecutionTargets` / `allowedExecutionTargets` | 27.0 | 27.0 | 27.0 | 27.0 | 27.0 |
