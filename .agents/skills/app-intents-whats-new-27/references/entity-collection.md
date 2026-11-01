# EntityCollection
**SDK Version:** iOS 27.0 and later

If the user's deployment target is below iOS 27 / macOS 27 / watchOS 27 / tvOS 27 / visionOS 27, the `EntityCollection<Entity>` type in this reference requires availability gating. It floors uniformly at 27.0 across iOS, macOS, watchOS, tvOS, and visionOS (declared `@available(anyAppleOS 27.0, *)`).

`EntityCollection<Entity>` is a value type that stores an ordered list of entity **identifiers** (`[Entity.ID]`) up front and defers materializing the full `AppEntity` instances until you explicitly ask for them. Use it anywhere you would otherwise hold a large `[Entity]` but only need the identifiers for most of the work — a Shortcuts action operating on hundreds of selected items, a batch mutation keyed by id, or an `@Property` on an entity that references many others. The win is at parameter-resolution time: a `@Parameter var items: [Entity]` forces the system to resolve every id into a fully hydrated entity before your `perform()` runs; `@Parameter var items: EntityCollection<Entity>` hands you the ids cheaply and lets you resolve on demand.

## `[Entity]` vs `EntityCollection<Entity>` as a parameter

The core adoption decision. With `[Entity]`, the system resolves and hydrates every identifier into a full entity during parameter resolution — for hundreds of entities that is expensive memory and time at a critical moment. With `EntityCollection<Entity>`, resolution only carries the identifiers; you hydrate later (or never, if you only need ids).

```swift
// AVOID: forces the system to hydrate every entity during parameter resolution.
struct DisableAlarmsIntent: AppIntent {
    static var title: LocalizedStringResource = "Disable Alarms"

    @Parameter(title: "Alarms")
    var alarms: [AlarmEntity]   // hundreds of full entities materialized up front

    func perform() async throws -> some IntentResult {
        try await AlarmService.disable(alarms.map(\.id))
        return .result()
    }
}

// PREFER: identifiers carried cheaply; no forced hydration.
@available(iOS 27.0, *)
struct DisableAlarmsIntent: AppIntent {
    static var title: LocalizedStringResource = "Disable Alarms"

    @Parameter(title: "Alarms")
    var alarms: EntityCollection<AlarmEntity>

    func perform() async throws -> some IntentResult {
        // Only ids are needed, so nothing is hydrated.
        try await AlarmService.disable(alarms.identifiers)
        return .result()
    }
}
```

**Availability:** `EntityCollection<Entity>` is iOS 27.0, macOS 27.0, watchOS 27.0, tvOS 27.0, visionOS 27.0.

## Constructing a collection

`init(identifiers:)` is the cheap path — it stores the ids and nothing else (the `identifiers:` argument defaults to `[]`, so `EntityCollection()` gives an empty collection). `init(entities:)` maps each entity to its id **and** pre-caches the entity instances, so a later `resolvedEntities()` returns them without a query. `EntityCollection` also conforms to `ExpressibleByArrayLiteral` over `Entity.ID`, so an array literal of ids is sugar for `init(identifiers:)`.

```swift
@available(iOS 27.0, *)
func makeCollections(ids: [AlarmEntity.ID], entities: [AlarmEntity]) {
    let cheap = EntityCollection<AlarmEntity>(identifiers: ids)   // ids only
    let cached = EntityCollection(entities: entities)            // pre-caches entities
    let literal: EntityCollection<AlarmEntity> = [ids[0], ids[1]] // array-literal sugar
    _ = (cheap, cached, literal)
}
```

**Availability:** `init(identifiers:)`, `init(entities:)`, and the `ExpressibleByArrayLiteral` conformance are iOS 27.0, macOS 27.0, watchOS 27.0, tvOS 27.0, visionOS 27.0.

## Hydrating with `resolvedEntities()`

When you need the full entities, call `resolvedEntities() async throws -> [Entity]`. If the collection was built with `init(entities:)` (or has already been resolved once), it returns the cached instances; otherwise it uses `Entity.defaultQuery` to fetch them and caches the result, so the second call is free. Hydrate once and reuse — do not call it inside a hot loop.

```swift
@available(iOS 27.0, *)
func perform(alarms: EntityCollection<AlarmEntity>) async throws {
    // AVOID: re-resolving per iteration (each call may run the default query).
    for id in alarms.identifiers {
        let all = try await alarms.resolvedEntities()   // wasteful in a loop
        _ = all.first { $0.id == id }
    }

    // PREFER: hydrate once, then work against the array.
    let entities = try await alarms.resolvedEntities()
    for entity in entities {
        await process(entity)
    }
}
```

**Availability:** `resolvedEntities()` is iOS 27.0, macOS 27.0, watchOS 27.0, tvOS 27.0, visionOS 27.0.

## Working with the identifiers

The `identifiers` property is public and directly accessible. `count` and `isEmpty` report on the identifiers without hydrating. `EntityCollection` conforms to `Collection` with `Element == Entity.ID`, so iterating it yields **identifiers, not entities**. Mutating helpers `append(_:)` (by id or by entity), `append(contentsOf:)`, and `remove(_:)` (by id or entity, requires `Entity.ID: Equatable`) let you edit the id list in place, and `contains(_:)` (by id or entity, `Entity.ID: Equatable`) checks membership — all without touching the hydration cache.

```swift
@available(iOS 27.0, *)
func editCollection(_ alarms: inout EntityCollection<AlarmEntity>, extra: AlarmEntity) {
    guard !alarms.isEmpty else { return }
    for id in alarms {                 // Collection iteration yields Entity.ID
        print(id)
    }
    alarms.append(extra)               // appends extra.id
    if alarms.contains(extra) {        // membership by entity (Entity.ID: Equatable)
        alarms.remove(extra)
    }
    print(alarms.count)
}
```

**Availability:** `identifiers`, `count`, `isEmpty`, the `Collection` conformance, and the `append`/`remove`/`contains` helpers are iOS 27.0, macOS 27.0, watchOS 27.0, tvOS 27.0, visionOS 27.0.

## Using it as `@Parameter` and `@Property`

`EntityCollection` is usable both as an app intent `@Parameter` and as an `@Property` on an `AppEntity` — the same deferred-hydration behavior applies in both roles. As a property it lets an entity reference many related entities by id without forcing those references to hydrate whenever the owning entity is materialized.

```swift
@available(iOS 27.0, *)
struct PlaylistEntity: AppEntity {
    let id: UUID

    @Property(title: "Songs")
    var songs: EntityCollection<SongEntity>   // ids stored; hydrate on demand

    static var defaultQuery = PlaylistQuery()
}
```

**Availability:** usage as `@Parameter` and `@Property` follows the type's floor — iOS 27.0, macOS 27.0, watchOS 27.0, tvOS 27.0, visionOS 27.0.

## Traps

`Equatable` on `EntityCollection` compares **identifiers only** — the hydration cache is ignored, so a freshly-built `init(identifiers:)` collection and an `init(entities:)` collection with the same ids compare equal even though one has cached entities and the other doesn't. Don't rely on `==` to tell you whether entities have been hydrated. And because `resolvedEntities()` runs the default query on a cold collection, calling it repeatedly (e.g. once per loop iteration) defeats the whole point of deferring hydration — resolve once, then iterate the returned `[Entity]`.

## Deployment target below SDK 27

When the user's deployment target is below SDK 27 and the answer needs `EntityCollection`, gate the parameter, property, or enclosing declaration behind an availability check and provide a fallback for older OS versions:

```swift
@available(iOS 27.0, *)
struct DisableAlarmsIntent: AppIntent {
    static var title: LocalizedStringResource = "Disable Alarms"

    @Parameter(title: "Alarms")
    var alarms: EntityCollection<AlarmEntity>

    func perform() async throws -> some IntentResult {
        try await AlarmService.disable(alarms.identifiers)
        return .result()
    }
}
```

Gate to the type's real floor: iOS 27.0 / macOS 27.0 / watchOS 27.0 / tvOS 27.0 / visionOS 27.0. For deployment targets below 27, keep a `[Entity]` (or `[Entity.ID]`) parameter as the fallback path. Don't emit unconditional uses of `EntityCollection`; the typecheck will fail with `'EntityCollection' is only available in iOS 27.0 or newer`.

## Availability summary

| API | iOS | macOS | watchOS | tvOS | visionOS |
|-----|-----|-------|---------|------|----------|
| `EntityCollection<Entity>` (type) | 27.0 | 27.0 | 27.0 | 27.0 | 27.0 |
| `init(identifiers:)` / `init(entities:)` / array-literal | 27.0 | 27.0 | 27.0 | 27.0 | 27.0 |
| `identifiers` / `count` / `isEmpty` | 27.0 | 27.0 | 27.0 | 27.0 | 27.0 |
| `resolvedEntities()` | 27.0 | 27.0 | 27.0 | 27.0 | 27.0 |
| `Collection` conformance (yields `Entity.ID`) | 27.0 | 27.0 | 27.0 | 27.0 | 27.0 |
| `append` / `remove` / `contains` | 27.0 | 27.0 | 27.0 | 27.0 | 27.0 |
| Use as `@Parameter` / `@Property` | 27.0 | 27.0 | 27.0 | 27.0 | 27.0 |
