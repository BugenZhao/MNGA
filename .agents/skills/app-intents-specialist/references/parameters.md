# Parameters and Resolution

`@Parameter` looks like a plain stored property, but its resolution is a small state machine the framework drives before and during `perform()` — and four of its behaviors contradict the property-wrapper mental model. A missing value can be resolved *inline* or by *restarting* `perform()`, and the two spellings are not interchangeable. A non-optional parameter does not always throw when unfilled — sometimes the framework silently asks the user to pick. Options that depend on another parameter cannot read that parameter directly. And a parameter you never name in your `Summary` simply does not appear in the Shortcuts editor. Each has a distinct trap; the sections below cover all four. (Restart semantics and flow-control-vs-failure are `execution-model.md`'s domain — this file assumes them.)

## Resolve a missing value inline with `requestValue`, or restart with `needsValueError` — they are not the same

Both `$param.requestValue(_:)` and `$param.needsValueError(_:)` prompt the user for a value, but they run at opposite ends of a spectrum. `requestValue(_:)` is `async` — you `await` it and it returns the resolved value *inline*, so the code after it keeps running in the same `perform()` invocation. `needsValueError(_:)` returns an `AppIntentError` you `throw` — it aborts the current pass and re-runs `perform()` from the top with the value now filled. Reach for the wrong one and you either can't get a value where you need it, or you silently opt into a restart (and its replay hazard).

```swift
// AVOID: throwing needsValueError to get a value you need *right here*. This
// doesn't return the value — it aborts and restarts perform() from the top, so
// the two lines below never run on this pass. Worse, any side effect already
// committed this pass replays on the restart.
func perform() async throws -> some IntentResult {
    try await log.append("starting split")          // committed…
    guard let payer else {
        throw $payer.needsValueError("Who paid?")     // …restart replays the append
    }
    let share = try await splitService.compute(for: payer)
    return .result(value: share)
}
```

```swift
// PREFER: requestValue when you need the value inline. It's async — await it and
// the resolved value flows into the same invocation; nothing restarts, nothing
// replays. Reserve needsValueError for when a restart is what you actually want.
func perform() async throws -> some IntentResult {
    let payer = try await $payer.requestValue("Who paid?")   // returns inline
    try await log.append("starting split")
    let share = try await splitService.compute(for: payer)
    return .result(value: share)
}
```

Do not reach for the old `requestValue(_:) -> Error` spelling that returns an `Error` to throw — it is `@available(*, deprecated)` and its message points you at exactly these two replacements. If a `requestValue` call returns something you `throw` rather than a value you `await`, you are on the deprecated overload.

## A non-optional `AppEnum` parameter auto-disambiguates — it does not throw a needs-value error

The rule "an unfilled non-optional `@Parameter` throws a needs-value error" is only half true. When such a parameter's type is an `AppEnum`, the framework instead gathers the enum's options and *auto-disambiguates*: with more than one option it asks the user to pick; with exactly one option it silently assigns that option and moves on. Only non-enum non-optional parameters fall through to a plain needs-value error. So a summary/dialog you write assuming "the user will be asked to type a value" is wrong for enums — they get a picker, driven by your `requestDisambiguationDialog`, not your `requestValueDialog`.

```swift
// AVOID: relying on a needs-value prompt for a non-optional AppEnum, and leaving
// the disambiguation dialog unset. The framework auto-disambiguates a multi-case
// enum with a *picker*, and falls back to a generic dialog — the user sees no
// useful prompt. (And a single-case enum is auto-assigned with no prompt at all.)
struct SetPriorityIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Priority"
    @Parameter(title: "Priority")
    var priority: TaskPriority        // AppEnum: .low, .medium, .high
    // ...
}
```

```swift
// PREFER: provide requestDisambiguationDialog — that's the prompt the auto-
// disambiguation actually uses for a multi-case AppEnum. requestValueDialog is
// the wrong slot for an enum; it's the fallback for non-enum types.
struct SetPriorityIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Priority"
    @Parameter(
        title: "Priority",
        requestDisambiguationDialog: "Which priority level?"
    )
    var priority: TaskPriority
    // ...
}
```

The single-case corollary matters for review: an `AppEnum` (or dynamic options list) that resolves to exactly one option is assigned with no user interaction, so any UI you expected around "the user chose the priority" never happens.

## Options that depend on another parameter need `@IntentParameterDependency` — you cannot read the sibling `@Parameter`

Inside a `DynamicOptionsProvider` or `EntityQuery`, the enclosing intent's other `@Parameter`s are not yet filled — reading them gives you nothing usable, because option-fetching runs *before* full resolution. To base one parameter's options on another's chosen value, declare an `@IntentParameterDependency<TheIntent>(\.$otherParam)` inside the provider/query and read the depended-on value through its projection. This is the only supported channel for cross-parameter option logic.

```swift
// AVOID: trying to read a sibling parameter's value from inside the query. There
// is no instance of the intent to read here, and the value isn't resolved yet at
// options-fetch time — so this can't compile against the intent's parameters and
// has nothing to read even conceptually.
struct RoomQuery: EntityStringQuery {
    func entities(matching string: String) async throws -> [RoomEntity] {
        let building = /* ??? no access to BookRoomIntent.$building here */
        return try await RoomStore.rooms(in: building, matching: string)
    }
}
```

```swift
// PREFER: declare the dependency; read the other parameter through its projection.
struct RoomQuery: EntityStringQuery {
    @IntentParameterDependency<BookRoomIntent>(\.$building)
    var bookRoom

    func entities(matching string: String) async throws -> [RoomEntity] {
        guard let bookRoom else { return [] }        // building not yet chosen
        return try await RoomStore.rooms(in: bookRoom.building, matching: string)
    }
}
```

Guard the optional projection (`guard let bookRoom else { return [] }`) as shown — if the depended-on parameter is unset, the projection is unavailable and returning empty options is the graceful path. Do not force-unwrap the projected member: the wrapper `fatalError`s if you read a key path you did not list in the `@IntentParameterDependency`, so list every parameter you intend to read.

## Only parameters named in `Summary` show in the Shortcuts editor

`ParameterSummary` is not cosmetic — it is the allowlist for which parameters the Shortcuts editor surfaces. A parameter interpolated into the `ParameterSummaryString` (the `"…\(\.$param)…"` form) is shown; one added through the trailing `@ParameterKeyPathsBuilder` block of `Summary(_:)` is shown; every other `@Parameter` is silently omitted from the editor UI, even though it still exists and still resolves. So a parameter that "isn't editable in Shortcuts" is usually a parameter you forgot to mention in the summary — not a bug.

```swift
// AVOID: a summary that mentions only some parameters. `note` is interpolated so
// it shows; `folder` and `isPinned` are never named anywhere in the summary, so
// they simply don't appear in the Shortcuts editor — users can't set them.
static var parameterSummary: some ParameterSummary {
    Summary("Save \(\.$note)")
}
@Parameter(title: "Note")   var note: String
@Parameter(title: "Folder") var folder: FolderEntity
@Parameter(title: "Pinned") var isPinned: Bool
```

```swift
// PREFER: interpolate the parameters that belong in the sentence, and list the
// rest in the trailing key-path block so they still surface as editable rows.
static var parameterSummary: some ParameterSummary {
    Summary("Save \(\.$note) to \(\.$folder)") {
        \.$isPinned
    }
}
```

If a parameter should be user-configurable in Shortcuts, it must appear in the summary one way or the other. Omission is a valid choice for parameters that are only ever filled programmatically (e.g. from a preceding intent's output) — but make it a deliberate one.

