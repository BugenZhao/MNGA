# Configuration Intents: Describing a Widget or Control, Not Running One

`WidgetConfigurationIntent` (iOS 17) and `ControlConfigurationIntent` (iOS 18 / macOS 26) look like ordinary `AppIntent`s — they conform to `AppIntent`, they carry `@Parameter`s, they have a `title` — but they are *not* actions. They exist so WidgetKit can render a configuration screen: each `@Parameter` becomes one editable field in the widget-editing sheet or the Control Center picker, and the chosen values are handed back to your `TimelineProvider` / control provider to build the view. Nothing "runs." The framework supplies a default `perform()` for both protocols that immediately throws (returning `Never`), precisely so you never write one — the compiler will happily let you add your own, which is the whole trap. The sections below cover the mistakes that follow from treating a configuration intent as if it executed.

## The `@Parameter`s ARE the whole intent — don't add a `perform()` to "make it work"

A configuration intent's job is finished the moment its parameters are declared. The protocol already carries a default `perform()` (its result type is `Never`), so the type compiles and drives the configuration UI with an empty body. Writing your own `perform()` is not required and does not "activate" anything — at best it is dead code the system won't call as an action, at worst it hides real logic somewhere it will never run for a widget.

```swift
// AVOID: adding a perform() because the type "felt incomplete" without one, then
// putting the widget's data-loading in it. This body never runs to render the
// widget — WidgetKit reads the @Parameter values and calls your TimelineProvider;
// it does NOT execute the configuration intent as an action. The fetch here is
// dead on the widget path, and the .result() return type even fights the
// protocol's own Never-returning default. It compiles, so nothing warns you.
struct FavoriteBookConfig: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Favorite Book"

    @Parameter(title: "Book") var book: BookEntity?

    func perform() async throws -> some IntentResult {   // ❌ never invoked for the widget
        let cover = try await CoverLoader.load(for: book) // dead code on the render path
        return .result()
    }
}
```

```swift
// PREFER: parameters only. The @Parameters are the configuration surface; the
// framework's default perform() (returning Never) stands in, and WidgetKit passes
// the resolved values to your TimelineProvider, which does the actual data loading.
// Nothing to run, nothing to return.
struct FavoriteBookConfig: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Favorite Book"
    static let description = IntentDescription("Shows your favorite book.")

    @Parameter(title: "Book") var book: BookEntity?
    // no perform() — the timeline provider reads `book` and builds the view
}
```

The one legitimate reason to write `perform()` is to *reuse the same type* as a real, runnable action elsewhere. If you are not doing that, leave it off.

## A control that toggles a value is a `SetValueIntent` action — separate from the control's `ControlConfigurationIntent`

Control Center controls have two intents with two different jobs, and conflating them is common. `ControlConfigurationIntent` *describes* the control (which thing it points at — a specific Focus, a particular device); it has no `perform()`. The action the control fires when tapped — flipping a toggle, setting a level — is a real, runnable intent, and for the on/off case that is `SetValueIntent`, which very much *does* implement `perform()`.

```swift
// AVOID: trying to make the configuration intent do the toggling. A
// ControlConfigurationIntent has no perform() the system will run on tap, so the
// side effect below is orphaned — the control configures fine but never toggles.
struct SilentModeControl: ControlConfigurationIntent {
    static let title: LocalizedStringResource = "Silent Mode"
    @Parameter(title: "On") var isOn: Bool
    func perform() async throws -> some IntentResult {   // ❌ not the control's tap action
        SilentMode.shared.set(isOn); return .result()
    }
}
```

```swift
// PREFER: keep the two roles in two types. The SetValueIntent is the runnable
// action WidgetKit ties to the control's value; its perform() carries the real
// logic. If the control needs to point at a specific target, THAT selection is
// what a ControlConfigurationIntent's @Parameters describe.
struct ToggleSilentMode: SetValueIntent {
    static let title: LocalizedStringResource = "Silent Mode"
    @Parameter(title: "Silent") var value: Bool
    func perform() async throws -> some IntentResult {   // ✅ runs on tap
        SilentMode.shared.set(value); return .result()
    }
}
```

`SetValueIntent` is a normal action intent and follows the ordinary execution rules in `execution-model.md`; only the *configuration* half is the no-`perform()` case. Which parameters belong on the configuration intent — optional vs. defaulted so the system can preview the control before setup — is a parameter-design question covered in `parameters.md`, and whether a distinct configuration surface even warrants its own type is the granularity question in `factoring.md`.
