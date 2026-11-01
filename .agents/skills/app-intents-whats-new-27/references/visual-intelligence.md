# Visual Intelligence
**SDK Version:** iOS 26.0 and later

If the user's deployment target is below the availability listed for a given API in this reference (`IntentValueQuery` and `SemanticContentDescriptor` are iOS 26.0; `@UnionValue` / `AppUnionValue` are effectively iOS 27.0; `OpenIntent` back-deploys to iOS 16.0), the new usage requires availability gating. See "Deployment target below the API's floor" below for the gating shape to use.

Visual intelligence lets the system hand your app what the camera or a screenshot sees and ask which of your entities match: you supply the query, the result types, and the "open" intents that make each result actionable. The running example is **TravelTracking**, a travel app with a `LandmarkEntity` and a `LandmarkCollectionEntity`. Associating the entity on the *current screen* with "this" is a separate surface — see `onscreen-entities.md`; proactively surfacing entities (`RelevantEntities`, `AppEntityContext`) lives in `relevance-and-context.md`.

## IntentValueQuery for visual intelligence

`IntentValueQuery` answers a visual-intelligence search: the system hands you a `SemanticContentDescriptor` and you return the matching entities. Conform a type to `IntentValueQuery`, set `Input` to `SemanticContentDescriptor`, and implement `func values(for:) async throws`. `SemanticContentDescriptor` lives in the **VisualIntelligence** framework, not AppIntents — you must `import VisualIntelligence` or the `Input` type will not resolve. It exposes `public let labels: [String]` and `public var pixelBuffer: CVReadOnlyPixelBuffer?`, both read-only; you consume the descriptor, you never construct one. There is no separate "register this query" call — the system discovers the conformance through App Intents metadata extraction, the same way it finds `AppIntent` and `EntityQuery` types.

```swift
import AppIntents
import VisualIntelligence            // SemanticContentDescriptor lives here.

@available(iOS 26.0, *)
struct LandmarkIntentValueQuery: IntentValueQuery {
    // Input is the system-provided descriptor, not a String or your own type.
    func values(for input: SemanticContentDescriptor) async throws -> [LandmarkEntity] {
        let hints = input.labels                       // e.g. ["mountain", "peak"]
        return try await ModelData.shared.match(labels: hints,
                                                pixelBuffer: input.pixelBuffer)
    }
}
```

**Availability:** `IntentValueQuery` is `@available(anyAppleOS 26.0, *)`. `SemanticContentDescriptor` is `@available(iOS 26.0, macOS 27.0, macCatalyst 27.0, *)` (VisualIntelligence). Gate the query with `@available(iOS 26.0, *)`.

## @UnionValue for multiple result types

When one visual query can return more than one entity type — a `LandmarkEntity` or a `LandmarkCollectionEntity` — do not erase to `[any AppEntity]`, which loses per-type "open" targeting and display. Instead define a `@UnionValue` enum with one `case` per concrete type and return an array of it. (How `@UnionValue` expands and why the union type is gated at iOS 27.0 rather than the macro's own 18.0 floor is covered in `union-values.md`; here it's just the result type of the query.)

```swift
import AppIntents
import VisualIntelligence

@available(iOS 27.0, *)
@UnionValue
enum LandmarkResult {
    case landmark(LandmarkEntity)
    case collection(LandmarkCollectionEntity)
}

@available(iOS 27.0, *)
struct LandmarkIntentValueQuery: IntentValueQuery {
    func values(for input: SemanticContentDescriptor) async throws -> [LandmarkResult] {
        var results: [LandmarkResult] = []
        results += try await ModelData.shared.matchLandmarks(input).map(LandmarkResult.landmark)
        results += try await ModelData.shared.matchCollections(input).map(LandmarkResult.collection)
        return results
    }
}
```

**Availability:** gate a `@UnionValue` result type at `@available(iOS 27.0, *)` (the `AppUnionValue` conformance the union relies on is iOS 27.0, even though the `@UnionValue` macro itself back-deploys). Using a `@UnionValue` type as a Shortcuts *parameter* is covered in `union-values.md`.

## One OpenIntent per result type

A visual result is inert until tapping it opens something, so give each result type an `OpenIntent` and the system offers "open" on it. The VI-specific rule: an `OpenIntent`'s `Value` must be a **single concrete** `AppEntity`/`AppValue`, never the `@UnionValue` — so with a multi-type (`@UnionValue`) result you write **one `OpenIntent` per case type**. (`OpenIntent` itself — the `target`, `openAppWhenRun`, the default `perform()` — is covered in the specialist skill's `url-representation`.)

```swift
import AppIntents

@available(iOS 16.0, *)
struct OpenLandmarkIntent: OpenIntent {
    static let title: LocalizedStringResource = "Open Landmark"

    @Parameter(title: "Landmark")
    var target: LandmarkEntity             // OpenIntent.Value == LandmarkEntity
}

@available(iOS 16.0, *)
struct OpenLandmarkCollectionIntent: OpenIntent {
    static let title: LocalizedStringResource = "Open Landmark Collection"

    @Parameter(title: "Landmark Collection")
    var target: LandmarkCollectionEntity
}
```

**Availability:** `OpenIntent` is `@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)`.

## Availability summary

| API | iOS | macOS | watchOS | tvOS | visionOS |
|---|---|---|---|---|---|
| `IntentValueQuery` | 26.0 | 26.0 | 26.0 | 26.0 | 26.0 |
| `SemanticContentDescriptor`¹ | 26.0 | 27.0 | — | — | — |
| `@UnionValue` result type² | 27.0 | 27.0 | 27.0 | 27.0 | 27.0 |
| `OpenIntent` | 16.0 | 13.0 | 9.0 | 16.0 | 1.0³ |

¹ Ships from the **VisualIntelligence** framework (`import VisualIntelligence`), declared `@available(iOS 26.0, macOS 27.0, macCatalyst 27.0, *)` — note the mixed floor (iOS 26 but macOS 27); it is not part of AppIntents.
² The `@UnionValue` macro attribute is iOS 18.0, but a union usable as a result here conforms to `AppUnionValue` (iOS 27.0) — gate union *types* at iOS 27.0.
³ The interface declares `OpenIntent` as `@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)` — no explicit visionOS floor; visionOS availability (1.0) is implied by the trailing `*`, not enumerated.
