# Interactive Snippets
**SDK Version:** iOS 26.0 and later

If the user's deployment target is below iOS 26, the new APIs in this reference (the `SnippetIntent` protocol, the `ShowsSnippetIntent` capability and its `result(snippetIntent:)` factories, `requestConfirmation(actionName:snippetIntent:)`, `EmptySnippetIntent`, and `SnippetIntent.reload()`) require availability gating. The static `ShowsSnippetView` snippet (`result(view:)` / `result { }`, iOS 16.0) and the `Button(intent:)` / `Toggle(isOn:intent:)` controls (iOS 17.0) back-deploy further and do not need iOS 26 gating on their own — it is the *live-snippet refresh* behavior that is new. See "Deployment target below SDK 26" below for the gating shape to use.

Before iOS 26 an App Intent could only show a static snapshot from `result(view:)`, so any control inside it was dead — its taps ran no code. iOS 26 adds interactive snippets: model the snippet as a `SnippetIntent`, return it from the main intent with `result(snippetIntent:)`, and host `Button(intent:)` / `Toggle(isOn:intent:)` controls whose taps run real intents. Those control intents can re-present the same snippet (or call `reload()`) to refresh it in place. The running example is Apple's **Landmarks** sample (the `AppIntentsTravelTracker` app): `ClosestLandmarkIntent` returns a `LandmarkSnippetIntent` that renders a `LandmarkView`, whose `Button(intent:)` controls favorite the landmark (`UpdateFavoritesIntent`) or find tickets (`FindTicketsIntent`).

## SnippetIntent and ShowsSnippetIntent

`SnippetIntent` is an `AppIntent` whose `PerformResult` is constrained to `ShowsSnippetView` — its `perform()` returns `some IntentResult & ShowsSnippetView` (a `result(view:)` snippet from the SwiftUI overlay). The *main* intent hands the system a live snippet by composing `ShowsSnippetIntent` into its return type and calling `.result(snippetIntent:)`; the system can re-run that `SnippetIntent` to redraw. `EmptySnippetIntent` is the factory's default argument when there is no snippet to show.

```swift
@available(iOS 26.0, *)
struct ClosestLandmarkIntent: AppIntent {
    static let title: LocalizedStringResource = "Find Closest Landmark"
    @Dependency var modelData: ModelData

    func perform() async throws -> some ReturnsValue<LandmarkEntity> & ShowsSnippetIntent & ProvidesDialog {
        let landmark = await findClosestLandmark()
        return .result(
            value: landmark,
            dialog: IntentDialog(
                full: "The closest landmark is \(landmark.name).",
                supporting: "\(landmark.name) is located in \(landmark.continent)."
            ),
            snippetIntent: LandmarkSnippetIntent(landmark: landmark)
        )
    }
}

@available(iOS 26.0, *)
struct LandmarkSnippetIntent: SnippetIntent {
    static let title: LocalizedStringResource = "Landmark Snippet"

    @Parameter var landmark: LandmarkEntity
    @Dependency var modelData: ModelData

    init() {}
    init(landmark: LandmarkEntity) { self.landmark = landmark }

    func perform() async throws -> some IntentResult & ShowsSnippetView {
        let isFavorite = await modelData.isFavorite(landmark)   // READ only
        return .result(view: LandmarkView(landmark: landmark, isFavorite: isFavorite))
    }
}
```

An intent you **construct with parameter values** — to pass as `snippetIntent:`, wire to `Button(intent:)`, or hand to `requestConfirmation` — needs a **custom `init` that assigns its `@Parameter`s**, plus the required no-argument `init()`. (Every snippet/control intent shown below does the same.)

**Availability:** the `SnippetIntent` protocol, `ShowsSnippetIntent`, `EmptySnippetIntent`, and the `result(snippetIntent:)` factories are iOS 26.0 (base AppIntents module). The `ShowsSnippetView` capability and the overlay `result(view:)` / `result { }` factories the snippet's own `perform()` returns are iOS 16.0.

## result(snippetIntent:) vs result(view:)

The two live at different layers. The **main** intent calls `result(snippetIntent:)` (iOS 26.0) to hand the system a `SnippetIntent` it can re-run to redraw — use it whenever the card has controls that act or state that changes. A `SnippetIntent` (or any display-only intent) renders its card with `result(view:)` (iOS 16.0, SwiftUI overlay), which bakes a one-time SwiftUI snapshot from the values captured at return time and never re-runs code. `result(snippetIntent:)` comes in `value:` / `dialog:` / `opensIntent:` combinations (as in `ClosestLandmarkIntent` above).

```swift
// Main intent: hand over a live snippet the system can re-run.
return .result(value: landmark, dialog: dialog,
               snippetIntent: LandmarkSnippetIntent(landmark: landmark))

// Inside the SnippetIntent (or a display-only intent): render a one-time snapshot.
return .result(view: LandmarkView(landmark: landmark, isFavorite: isFavorite))
```

**Availability:** `result(snippetIntent:)` and its `value:` / `dialog:` / `opensIntent:` combinations are iOS 26.0. `result(view:)` / `result { }` and their combinations are iOS 16.0 (active when the target imports both AppIntents and SwiftUI).

## Interactive controls with Button(intent:) and Toggle(isOn:intent:)

Inside a snippet view, wire controls to intents — `Button(intent:)` and `Toggle(isOn:intent:)` — never to closures. A tapped control runs the intent; `Button(action:)` / `.onTapGesture` closures inside a snippet run no code. `LandmarkView` wires a favorite button and a find-tickets button to their control intents:

```swift
struct LandmarkView: View {
    let landmark: LandmarkEntity
    let isFavorite: Bool

    var body: some View {
        // ...
        Button(intent: UpdateFavoritesIntent(landmark: landmark, isFavorite: !isFavorite)) {
            Label(isFavorite ? "Remove Favorite" : "Add Favorite", systemImage: "star")
        }
        Button(intent: FindTicketsIntent(landmark: landmark)) {
            Text("Find Tickets")
        }
        // ...
    }
}
```

For boolean state you can pair a `Toggle(isOn:intent:)` instead of a button — note `isOn:` takes a plain `Bool`, not a `Binding<Bool>`: the toggle doesn't own the state, the control intent does.

**Availability:** `Button(intent:)` and `Toggle(isOn:intent:)` are iOS 17.0 (SwiftUI cross-import overlay). They compile in any SwiftUI view; their *refresh-a-live-snippet* behavior requires the iOS 26.0 `SnippetIntent` host.

## Confirmation snippets with requestConfirmation(snippetIntent:)

A control intent can present its own snippet mid-run to confirm an action. `requestConfirmation(actionName:snippetIntent:)` (iOS 26.0) shows a `SnippetIntent` and suspends until the person confirms. `FindTicketsIntent` confirms a ticket search with a `TicketRequestSnippetIntent`:

```swift
@available(iOS 26.0, *)
struct FindTicketsIntent: AppIntent {
    static let title: LocalizedStringResource = "Find Tickets"

    @Parameter var landmark: LandmarkEntity
    @Dependency var searchEngine: SearchEngine

    init() {}
    init(landmark: LandmarkEntity) { self.landmark = landmark }

    func perform() async throws -> some IntentResult {
        let searchRequest = await searchEngine.createRequest(landmarkEntity: landmark)
        // Present a snippet that lets people adjust the request, then confirm.
        try await requestConfirmation(
            actionName: .search,
            snippetIntent: TicketRequestSnippetIntent(searchRequest: searchRequest)
        )
        // ...resume searching once confirmed...
        return .result()
    }
}

@available(iOS 26.0, *)
struct TicketRequestSnippetIntent: SnippetIntent {
    static let title: LocalizedStringResource = "Ticket Request Snippet"

    @Parameter var searchRequest: SearchRequestEntity

    init() {}
    init(searchRequest: SearchRequestEntity) { self.searchRequest = searchRequest }

    func perform() async throws -> some IntentResult & ShowsSnippetView {
        .result(view: TicketRequestView(searchRequest: searchRequest))
    }
}
```

**Availability:** `requestConfirmation(actionName:snippetIntent:)` is iOS 26.0.

## Refresh in place

The refresh paths are distinct — don't conflate them:

- **A control intent (a `Button` / `Toggle` tap) just returns `.result()`.** After it completes, the system **automatically re-runs the hosting `SnippetIntent.perform()`** and redraws with fresh state — you do *not* re-present the snippet from the control intent.
- **`.result(snippetIntent:)`** is for the *originating* or *transition* intent — the one that first shows a snippet, or switches to a *different* one.
- **`SnippetIntent.reload()`** refreshes the snippet from *outside* a tap — an out-of-band / `async` update completing elsewhere. Call it from that async context; it is not a substitute for the automatic re-run after a tap.

Put every mutation in the *control* intent, never in the snippet's `perform()` — and never point `Button(intent:)` / `Toggle(isOn:intent:)` at the `SnippetIntent` itself; always target a separate action intent.

```swift
// Control intent invoked by a snippet button: do the work, then just return .result().
// The system re-runs LandmarkSnippetIntent.perform() and redraws automatically.
@available(iOS 26.0, *)
struct UpdateFavoritesIntent: AppIntent {
    static let title: LocalizedStringResource = "Update Favorites"

    @Parameter var landmark: LandmarkEntity
    @Parameter var isFavorite: Bool
    @Dependency var modelData: ModelData

    init() {}
    init(landmark: LandmarkEntity, isFavorite: Bool) {
        self.landmark = landmark
        self.isFavorite = isFavorite
    }

    func perform() async throws -> some IntentResult {
        await modelData.setFavorite(landmark, isFavorite: isFavorite)   // the mutation
        return .result()                                               // no re-present needed
    }
}

// Out-of-band refresh (not a tap): re-run the snippet's perform() as async work completes.
@available(iOS 26.0, *)
func performRequest(_ request: SearchRequestEntity) async throws {
    // set a pending status...
    TicketResultSnippetIntent.reload()   // redraw: pending

    // ...await the search...
    TicketResultSnippetIntent.reload()   // redraw: results
}
```

**Availability:** `result(snippetIntent:)` and the static `SnippetIntent.reload()` are iOS 26.0.

## Side-effect-free SnippetIntent.perform()

`SnippetIntent.perform()` must be idempotent and side-effect-free: the system may re-run it on any redraw (state restoration, `reload()`, live refresh), so it must be a pure read that renders current state. `LandmarkSnippetIntent` only reads (`modelData.isFavorite(landmark)`); the mutation lives in `UpdateFavoritesIntent`, which the snippet's button invokes.

```swift
@available(iOS 26.0, *)
struct LandmarkSnippetIntent: SnippetIntent {
    static let title: LocalizedStringResource = "Landmark Snippet"

    @Parameter var landmark: LandmarkEntity
    @Dependency var modelData: ModelData

    init() {}
    init(landmark: LandmarkEntity) { self.landmark = landmark }

    func perform() async throws -> some IntentResult & ShowsSnippetView {
        // READ current state only — safe to run repeatedly.
        let isFavorite = await modelData.isFavorite(landmark)
        return .result(view: LandmarkView(landmark: landmark, isFavorite: isFavorite))
    }
}
```

**Availability:** iOS 26.0.

## Deployment target below SDK 26

When the user's deployment target is below SDK 26 and the answer needs interactive snippets, don't try to branch the two snippet styles inside one `perform()`: a single opaque `some IntentResult` return can't yield `.result(snippetIntent:)` on one path and the static `.result(view:)` overlay on another, because those are two different concrete result types and an opaque return must resolve to exactly one (the build fails with "do not have matching underlying types"). Instead gate at the *declaration* level — mark the interactive intent `@available(iOS 26.0, *)` and provide a separate, independently-typed fallback intent that returns a static result for earlier OSes.

```swift
// New: interactive-snippet intent, gated at the declaration.
@available(iOS 26.0, *)
struct ClosestLandmarkIntent: AppIntent {
    static let title: LocalizedStringResource = "Find Closest Landmark"
    @Dependency var modelData: ModelData

    func perform() async throws -> some ReturnsValue<LandmarkEntity> & ShowsSnippetIntent & ProvidesDialog {
        let landmark = await findClosestLandmark()
        return .result(value: landmark,
                       dialog: "The closest landmark is \(landmark.name).",
                       snippetIntent: LandmarkSnippetIntent(landmark: landmark))
    }
}

// Older targets: a separate intent returning a static, display-only result.
struct ClosestLandmarkLegacyIntent: AppIntent {
    static let title: LocalizedStringResource = "Find Closest Landmark"
    @Dependency var modelData: ModelData

    func perform() async throws -> some ReturnsValue<LandmarkEntity> & ProvidesDialog {
        let landmark = await findClosestLandmark()
        return .result(value: landmark,
                       dialog: "The closest landmark is \(landmark.name).")
    }
}
```

The `Button(intent:)` / `Toggle(isOn:intent:)` controls (iOS 17.0) and `result(view:)` (iOS 16.0) don't themselves need iOS 26 gating — only their use to refresh a live snippet does. Don't emit unconditional calls to `result(snippetIntent:)`, `requestConfirmation(actionName:snippetIntent:)`, the `SnippetIntent` protocol, or `SnippetIntent.reload()` on a sub-26 target; the typecheck will fail with `'<API>' is only available in iOS 26.0 or newer`.

## Availability summary

| API | iOS | macOS | watchOS | tvOS | visionOS |
|---|---|---|---|---|---|
| `SnippetIntent` protocol | 26 | 26 | 26 | 26 | 26 |
| `ShowsSnippetIntent`, `result(snippetIntent:)` | 26 | 26 | 26 | 26 | 26 |
| `requestConfirmation(actionName:snippetIntent:)` | 26 | 26 | 26 | 26 | 26 |
| `EmptySnippetIntent` | 26 | 26 | 26 | 26 | 26 |
| `SnippetIntent.reload()` | 26 | 26 | 26 | 26 | 26 |
| `ShowsSnippetView`, `result(view:)` / `result { }` | 16 | 13 | 9 | 16 | 1 |
| `Button(intent:)` / `Toggle(isOn:intent:)` | 17 | 14 | 10 | 17 | 1 |
