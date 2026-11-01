# Convenience Property Macros
**SDK Version:** iOS 26.0 and later

If the user's deployment target is below iOS 26 / macOS 26 / watchOS 26 / tvOS 26 / visionOS 26, the new APIs in this reference (`@ComputedProperty` and `@DeferredProperty`, including their `title:`, `indexingKey:`, and `customIndexingKey:` overloads) require availability gating. The base `@ComputedProperty()` / `@ComputedProperty(title:)` and `@DeferredProperty()` / `@DeferredProperty(title:)` macros floor at 26.0 across iOS, macOS, watchOS, tvOS, and visionOS; the CoreSpotlight `indexingKey:` / `customIndexingKey:` overloads are iOS 26.0 / macOS 26.0 / visionOS 26.0 only (no watchOS/tvOS). See "Deployment target below SDK 26" below for the gating shape to use.

`@ComputedProperty` and `@DeferredProperty` are peer/accessor macros for `AppEntity` properties that project a value from the entity's source of truth at access time instead of snapshotting a stale copy into a stored `@Property`. `@ComputedProperty` reads synchronously and cheaply; `@DeferredProperty` backs an `get async throws` accessor for expensive or lazy values. Both are read-only projections: apply them only to derived, non-writable values — never to `id` or to any user-editable state, which stays a stored `@Property`. Because these run against the backing model, the store is threaded into the entity through its `init` (from its `EntityQuery`), not injected onto the entity.

## @ComputedProperty

`@ComputedProperty` attaches `get`/`set` accessors to an `AppEntity` property that reads **synchronously** from the entity's backing model on every access, so the value is always current with no manual refresh path. Use it when the value is always in memory and computing it is cheap (a field lookup or trivial format). The bare `@ComputedProperty()` and `@ComputedProperty(title:)` forms carry the value; the getter body must be non-async and non-throwing.

```swift
@available(iOS 26.0, *)
struct LandmarkEntity: AppEntity {
    let id: UUID
    private let store: ModelData

    init(id: UUID, store: ModelData) {
        self.id = id
        self.store = store
    }

    @ComputedProperty
    var isFavorite: Bool { store.landmark(id)?.isFavorite ?? false }

    static var defaultQuery = LandmarkEntityQuery()
}
```

**Availability:** `@ComputedProperty()` and `@ComputedProperty(title:)` are iOS 26.0, macOS 26.0, watchOS 26.0, tvOS 26.0, visionOS 26.0.

## @ComputedProperty with Spotlight indexing

`@ComputedProperty(indexingKey:)` and `@ComputedProperty(title:indexingKey:)` take a `PartialKeyPath<CSSearchableItemAttributeSet>`, and `@ComputedProperty(customIndexingKey:)` / `@ComputedProperty(title:customIndexingKey:)` take a `CSCustomAttributeKey`, mapping the computed value into a Spotlight attribute in one declaration. These overloads map the computed value into CoreSpotlight's `CSSearchableItemAttributeSet`, and AppIntents gates them off watchOS/tvOS, so they are narrower than the base macro.

```swift
@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
@available(watchOS, unavailable) @available(tvOS, unavailable)
extension LandmarkEntity {
    @ComputedProperty(title: "Name", indexingKey: \.displayName)
    var indexedName: String { store.landmark(id)?.name ?? "" }
}
```

**Availability:** the `indexingKey:` and `customIndexingKey:` overloads are iOS 26.0, macOS 26.0, visionOS 26.0 (no watchOS/tvOS).

## @DeferredProperty

`@DeferredProperty` has the same shape as `@ComputedProperty` (attaches `get`/`set`), but the backing getter is declared `get async throws` — the system evaluates it lazily, only when the value is actually needed, and it can await and throw. Use it for values that require I/O, network, decoding, or a slow computation you don't want to pay on every entity materialization. The bare `@DeferredProperty()` and `@DeferredProperty(title:)` forms carry the value.

```swift
@available(iOS 26.0, *)
struct LandmarkEntity: AppEntity {
    let id: UUID
    private let store: ModelData

    init(id: UUID, store: ModelData) {
        self.id = id
        self.store = store
    }

    @DeferredProperty(title: "Conditions")
    var conditions: String {
        get async throws {
            try await store.fetchWeather(id).summary
        }
    }

    static var defaultQuery = LandmarkEntityQuery()
}
```

**Availability:** `@DeferredProperty()` and `@DeferredProperty(title:)` are iOS 26.0, macOS 26.0, watchOS 26.0, tvOS 26.0, visionOS 26.0.

## @DeferredProperty with Spotlight indexing

`@DeferredProperty(indexingKey:)` and `@DeferredProperty(title:indexingKey:)` take a `PartialKeyPath<CSSearchableItemAttributeSet>`, mapping the deferred value into a Spotlight attribute. As with `@ComputedProperty`, these bridge to CoreSpotlight and are unavailable on watchOS/tvOS. `@DeferredProperty` has no `customIndexingKey:` overload.

```swift
// Gate the enclosing type/extension, never the property.
@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
@available(watchOS, unavailable) @available(tvOS, unavailable)
extension LandmarkEntity {
    @DeferredProperty(title: "Conditions", indexingKey: \.contentDescription)
    var conditions: String {
        get async throws {
            try await store.fetchWeather(id).summary
        }
    }
}
```

**Availability:** the `indexingKey:` overloads are iOS 26.0, macOS 26.0, visionOS 26.0 (no watchOS/tvOS).

## Read-only projections only

Both macros produce read-only projections of the entity's source of truth. Never apply `@ComputedProperty` or `@DeferredProperty` to `id` or to any writable, user-editable value — identity and intent-input state stay a stored `let` or `@Property`. Keep the `@ComputedProperty` body synchronous, non-throwing, and free of I/O; if the value needs to await or throw, it belongs in `@DeferredProperty`'s `get async throws` accessor instead.

## Deployment target below SDK 26

When the user's deployment target is below SDK 26 and the answer needs any of the macros above, gate the **enclosing type or extension** behind an availability check and provide a fallback for older OS versions:

```swift
@available(iOS 26.0, *)
extension LandmarkEntity {
    @ComputedProperty
    var isFavorite: Bool { store.landmark(id)?.isFavorite ?? false }
}
```

Gate to the macro's real floor: the base `@ComputedProperty()` / `@DeferredProperty()` (and their `title:` forms) at iOS 26.0 / macOS 26.0 / watchOS 26.0 / tvOS 26.0 / visionOS 26.0, and the `indexingKey:` / `customIndexingKey:` overloads at iOS 26.0 / macOS 26.0 / visionOS 26.0 only (no watchOS/tvOS). For deployment targets below 26, keep a stored `@Property` fallback populated in `init` for the older path. Don't emit unconditional uses of these macros; the typecheck will fail with `'ComputedProperty' is only available in iOS 26.0 or newer`.
