# Execution Model of `perform()`

`perform()` does not run the way its name suggests. It is declared `func perform() async throws -> some IntentResult` on a `Sendable` protocol with **no actor isolation**, it runs in whatever process hosts the intent (your app *or* an app extension), and the system may re-invoke it from the top during a single logical run. Each of those three facts contradicts the naive mental model — "an action that runs inside my already-running app, on the main thread, once" — and each has a distinct correctness trap. The sections below cover all three — plus the confirmation primitive that shares the same side-effect-ordering discipline.

## `perform()` is not `@MainActor` — hop before touching main-actor state

`AppIntent` conforms to `Sendable`, not `@MainActor`, and `perform()` carries no actor annotation. So the body may run off the main thread (and in a different process than your UI). Reading or writing `@MainActor`-isolated state directly from `perform()` — an `@Observable` view model, SwiftUI/UIKit/AppKit objects, anything annotated `@MainActor` — is a concurrency violation. It is *not* safe just because the intent "opens the app."

```swift
// AVOID: touching main-actor state directly from perform(). `navigator` and
// `libraryModel` are @MainActor; perform() is not, so these calls hop actors
// implicitly at best and race at worst. Under Swift 6 this won't compile.
struct OpenNoteIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Note"
    @Parameter var note: NoteEntity

    func perform() async throws -> some IntentResult {
        navigator.navigate(to: note)          // @MainActor — called off-main
        libraryModel.lastOpened = note.id     // @MainActor mutation — data race
        return .result()
    }
}
```

```swift
// PREFER: hop to the main actor explicitly for the work that needs it. Do the
// rest (validation, data lookups) where perform() already is.
struct OpenNoteIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Note"
    @Parameter var note: NoteEntity

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            navigator.navigate(to: note)
            libraryModel.lastOpened = note.id
        }
        return .result()
    }
    // Alternatively, since this whole body is main-actor work, annotate the method
    // and drop the wrapper: `@MainActor func perform() async throws -> some IntentResult`.
}
```

Calling an `@MainActor`-isolated method with `await` (e.g. `await navigator.open(note)`) is equally correct — the point is that the actor hop is *explicit*, not assumed. When *most* of `perform()` touches main-actor state, annotating the method — `@MainActor func perform() async throws -> some IntentResult` — is cleaner than wrapping the body in `MainActor.run { }`; keep the narrow `MainActor.run { }` / `await` hop when `perform()` also does heavy async or non-UI work you don't want pinned to the main actor. What you must **not** do is annotate the intent *type* `@MainActor`: `AppIntent`'s requirements are nonisolated, so a `@MainActor` intent type doesn't compile in the straightforward form (Swift 6 flags `#ConformanceIsolation` — e.g. "main actor-isolated static property 'title' cannot satisfy nonisolated requirement"), and forcing it (isolating the conformance to the main actor) would pin the whole intent — construction, parameter resolution, and `perform()` — to the main actor, which is not the framework's model.

## `perform()` can be re-invoked from the top — make side effects idempotent

A single logical run of an intent can execute your `perform()` body **more than once**. Requesting a missing parameter value (`$param.needsValueError(_:)`) and `AppIntentError.restartPerform` both abort the current pass and run `perform()` again from the beginning. The framework does **not** roll back side effects you already committed on the earlier pass — it just re-enters your function.

So a `perform()` written as a linear script — do the irreversible thing, *then* ask for something the system might need to prompt for — replays the irreversible thing on the restart.

```swift
// AVOID: irreversible side effect before a value request. If `recipient` is
// unset, needsValueError restarts perform() from the top — and the charge
// runs again on the second pass. The user is billed twice.
func perform() async throws -> some IntentResult {
    try await paymentService.charge(amount)            // irreversible, runs first
    guard let recipient else {
        throw $recipient.needsValueError("Send to whom?")  // restarts perform()
    }
    try await paymentService.send(amount, to: recipient)
    return .result(value: amount)
}
```

```swift
// PREFER: resolve and validate everything first; do the irreversible work last,
// after there is nothing left that can trigger a restart. If a restart is still
// possible around irreversible work, guard it with an idempotency key / state
// check so a replay is a no-op.
func perform() async throws -> some IntentResult {
    guard let recipient else {
        throw $recipient.needsValueError("Send to whom?")  // restart happens here…
    }
    // …by the time we reach the charge, all value requests are behind us.
    try await paymentService.charge(amount)
    try await paymentService.send(amount, to: recipient)
    return .result(value: amount)
}
```

Distinguish flow control from failure: `restartPerform` and `needsValueError` are *expected* control flow that preserve the run — don't catch and swallow them as if they were errors. Reserve thrown application errors for genuine failures (see `results-and-errors.md`).

## Confirm *before* destructive work — a cancel throws

`requestConfirmation(...)` is the third flow-control primitive, and it runs opposite to a value request: it `await`s inline in the *same* `perform()` pass, returns normally if the user confirms, and **throws** if they cancel. So it belongs immediately *before* the irreversible action — a cancel then propagates out and aborts `perform()` on its own. Confirming *after* the destructive work is theater, and catching the cancel with `try?` makes "confirm" and "cancel" do the same thing.

```swift
// AVOID: confirming after the destructive work, and swallowing the cancel. The
// notes are already gone; the prompt changes nothing, and `try?` makes a cancel
// indistinguishable from a confirm.
func perform() async throws -> some IntentResult {
    try await store.deleteAllNotes()          // irreversible — already happened
    try? await requestConfirmation(dialog: "Delete all notes?")
    return .result()
}
```

```swift
// PREFER: confirm first. A cancel throws and aborts perform() before anything
// destructive runs; the delete executes only on confirm.
func perform() async throws -> some IntentResult {
    try await requestConfirmation(dialog: "Delete all notes? This can't be undone.")
    try await store.deleteAllNotes()          // runs only if the user confirmed
    return .result()
}
```

The dialog-bearing `requestConfirmation(conditions:actionName:dialog:)` is iOS 18+; the parameterless `requestConfirmation()` is available since iOS 16. Either way, do not wrap the call in `do/catch` or `try?` to "handle" a cancel — let the thrown cancel abort the intent, which is exactly the intended behavior.

## Return through the `.result(...)` factories — never a bare value

`perform()`'s return type is `some IntentResult` (its `PerformResult` associated type). You never construct the result container yourself or return a domain type — you use the `IntentResult.result(...)` factory family, and compose optional outputs through the marker protocols `ReturnsValue<Value>`, `ProvidesDialog`, and `OpensIntent`.

```swift
// AVOID: returning a domain value or a hand-built type. It doesn't conform to
// IntentResult, so it won't compile — and reaching for `some IntentResult` while
// returning a custom struct is a common dead end.
func perform() async throws -> NoteSummary {        // ❌ not an IntentResult
    NoteSummary(count: notes.count)
}
```

```swift
// PREFER: return `some IntentResult` and build it with a `.result(...)` factory.
func perform() async throws -> some ReturnsValue<Int> {
    let count = try await store.noteCount()
    return .result(value: count)
}

// No value to return? `.result()` marks completion.
func perform() async throws -> some IntentResult {
    try await store.archiveAll()
    return .result()
}
```

Let the container type be inferred from the factory and the marker composition; declare only the markers you actually use. Do not name `IntentResultContainer` directly, and do not use the deprecated `OpensAppIntent` associated-type spelling — the current marker is `OpensIntent`.

