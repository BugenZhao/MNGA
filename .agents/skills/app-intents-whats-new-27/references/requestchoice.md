# Requesting a Choice Mid-Perform

**SDK Version:** iOS 26.0 and later

If the user's deployment target is below iOS 26 / macOS 26 / watchOS 26 / tvOS 26 / visionOS 26, the APIs in this reference (`requestChoice(between:dialog:)`, `IntentChoiceOption`, and `IntentChoiceOption.Style`) require availability gating. See "Deployment target below SDK 26" below for the gating shape to use.

Before iOS 26 an intent that needed the person to pick between a few options had to model that as a parameter and lean on disambiguation, or bounce into the app. iOS 26 adds `requestChoice(between:dialog:)`, which pauses `perform()` inline, shows a system prompt with a small set of options, and resumes with the option the person chose — no parameter, no app launch. It is the multi-option sibling of `requestConfirmation` (see `execution-modes.md` for continuation, and the specialist skill's `execution-model` for the general "confirm before destructive work" rule). Running example: the WWDC **TravelTracking** sample, whose `FindTicketsIntent` asks the person to pick a visit window before buying a ticket.

## requestChoice(between:dialog:)

`requestChoice(between:dialog:)` is an `async throws` method on `AppIntent`. Call it from `perform()` with an array of `IntentChoiceOption` and an optional `IntentDialog`; it returns the chosen `IntentChoiceOption`. Because `IntentChoiceOption` is `Equatable`, compare the return value against the options you built to branch. Reach for it when the choice is a small, fixed set decided *during* execution — not for open-ended entity selection (model that as a `@Parameter` and let resolution/disambiguation handle it).

```swift
@available(iOS 26.0, *)
struct FindTicketsIntent: AppIntent {
    static let title: LocalizedStringResource = "Find Tickets"
    @Parameter var landmark: LandmarkEntity

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let morning = IntentChoiceOption(title: "Morning visit")
        let evening = IntentChoiceOption(title: "Evening visit")

        let choice = try await requestChoice(
            between: [morning, evening],
            dialog: "When should the visit be?"
        )

        let window: VisitWindow = (choice == morning) ? .morning : .evening
        try await ModelData.shared.bookTicket(landmark, window: window)
        return .result(dialog: "Booked the \(window) visit.")
    }
}
```

**Availability:** iOS 26.0, macOS 26.0, watchOS 26.0, tvOS 26.0, visionOS 26.0.

## IntentChoiceOption and styling

`IntentChoiceOption(title:style:)` builds an option from a `LocalizedStringResource` title and an optional `Style` (default `.default`). Use `.destructive` for an option that deletes or is otherwise hard to undo — the system renders it accordingly. Include `IntentChoiceOption.cancel`, a system-provided option, when the person should be able to back out: **selecting `.cancel` makes `requestChoice` throw** (a cancellation error), so a cancel aborts `perform()` rather than returning — don't try to handle it as a returned value. (`Option` is a convenience type alias for `IntentChoiceOption`, declared on `AppIntent` — reference it as `Option` inside an intent, not `IntentChoiceOption.Option`.)

```swift
@available(iOS 26.0, *)
func perform() async throws -> some IntentResult {
    let keep   = IntentChoiceOption(title: "Keep both")
    let replace = IntentChoiceOption(title: "Replace existing", style: .destructive)

    // Selecting .cancel throws — it does not come back as a return value.
    let choice = try await requestChoice(between: [keep, replace, .cancel],
                                         dialog: "This landmark already exists.")
    if choice == replace {
        try await ModelData.shared.overwrite()
    }
    return .result()
}
```

**Availability:** iOS 26.0, macOS 26.0, watchOS 26.0, tvOS 26.0, visionOS 26.0. `IntentChoiceOption`, `IntentChoiceOption.Style` (`.default` / `.destructive` / `.cancel`), and the static `IntentChoiceOption.cancel` share the same availability.

## Deployment target below SDK 26

When the user's deployment target is below SDK 26 and the answer needs a mid-perform choice, gate the `requestChoice` path behind `@available` / `if #available` and fall back to the pre-26 approach (a `@Parameter` the person fills, or `requestConfirmation` for a binary choice):

```swift
func perform() async throws -> some IntentResult & ProvidesDialog {
    if #available(iOS 26.0, *) {
        let a = IntentChoiceOption(title: "Morning visit")
        let b = IntentChoiceOption(title: "Evening visit")
        let choice = try await requestChoice(between: [a, b], dialog: "When?")
        // ...branch on `choice`...
    } else {
        // Older fallback: resolve a parameter, or use requestConfirmation for a binary choice.
    }
    return .result(dialog: "Booked.")
}
```

Use this shape (or `@available(iOS 26.0, *)` on the enclosing declaration) whenever the prompt names a deployment target below SDK 26. Don't emit unconditional calls to `requestChoice` / `IntentChoiceOption`; the typecheck will fail with `'<API>' is only available in iOS 26.0 or newer`.

## Availability summary

| API | iOS | macOS | watchOS | tvOS | visionOS |
|---|---|---|---|---|---|
| `requestChoice(between:dialog:)` | 26.0 | 26.0 | 26.0 | 26.0 | 26.0 |
| `IntentChoiceOption` / `.Style` / `.cancel` | 26.0 | 26.0 | 26.0 | 26.0 | 26.0 |
