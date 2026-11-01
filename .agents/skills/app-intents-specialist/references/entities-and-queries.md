# Entities and Their Queries

An `AppEntity` is a *reference* the system stores, not a value it copies. When a person builds a shortcut around a `NoteEntity` or Siri fills a parameter with one, what actually gets persisted is the entity's `id` string — the entity is re-fetched later, possibly days later, possibly on a different device, by handing that `id` back to your `EntityQuery`. That indirection is where the non-obvious traps live: the `id` you choose has to survive round-trips you don't control, and the query has two *different* jobs (resolve-by-id vs. suggest-defaults) that look similar but are called in different situations and have different cost profiles. This file covers the identity contract and the query surface. Parameter *resolution* mechanics (the picker prompt, `@Parameter`) live in `parameters.md`.

## The `id` must be stable across launches — and across devices for synced entities

`AppEntity` refines `Identifiable` with `ID: EntityIdentifierConvertible & Sendable`, and the framework serializes that `id` into saved shortcuts and cross-device Siri sessions. It is not an in-memory handle — it is a durable reference the system stores and replays back to your query later. So an `id` derived from anything device-local or run-local breaks resolution the moment the storage outlives the state it was derived from.

```swift
// AVOID: an id sourced from device-local / run-local state. A Photos
// localIdentifier, a DB row id, or an array index is meaningful only in the
// process/device that minted it. Saved in a shortcut it resolves fine today;
// synced to the user's Mac (or after a re-import) the same string points at a
// different row or nothing — entities(for:) returns [] and the shortcut breaks
// with no obvious error.
struct NoteEntity: AppEntity {
    static let defaultQuery = NoteEntityQuery()
    var id: String                       // = String(arrayIndex)  ❌ positional
    // or: var id = asset.localIdentifier ❌ device-local
    @Property(title: "Title") var title: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(title)") }
}
```

```swift
// PREFER: a stable, globally meaningful id — a server-assigned key or a UUID
// you mint once and persist with the record. The same note resolves to the same
// entity on every launch and every device.
struct NoteEntity: AppEntity {
    static let defaultQuery = NoteEntityQuery()
    var id: UUID                         // minted once, stored with the record
    @Property(title: "Title") var title: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(title)") }
}
```

`String`, `UUID`, and `Int` get `EntityIdentifierConvertible` for free; a custom `id` type must conform and provide `entityIdentifierString` / `entityIdentifier(for:)` (keep the string ≤ 4096 chars — the framework truncates past that). Note that "unique per launch" is not enough: the identifier lands in *persisted* shortcuts and synced sessions, so it must be reproducible without any local index. If your local id genuinely differs per device (Photos `localIdentifier`, local DB row ids), that is a cross-device sync problem the framework addresses separately — evergreen advice is simply: choose a stable id up front.

## Only `@Property`-wrapped members are visible to the system

Wrapping a stored property with `@Property` is not decoration — it is what exposes the value to App Intents. Only `@Property` members are visible to Find intents, `EntityPropertyQuery` filtering, and parameter display; a plain `var` is private to your code and invisible to the system, even though both compile. Nothing warns you — a plain `var` simply never appears where you expected it to be filterable or displayed.

```swift
// AVOID: plain `var`s for data the system should see. `title` and `tagCount`
// look like part of the entity, but the system can't filter or surface them —
// they're invisible to Find intents and property queries.
struct NoteEntity: AppEntity {
    static let defaultQuery = NoteEntityQuery()
    var id: UUID
    var title: String          // ❌ invisible to the system
    var tagCount: Int          // ❌ invisible to the system
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(title)") }
}
```

```swift
// PREFER: wrap the properties the system should query/display with @Property.
// Keep plain `var`s only for values used purely inside your own code (e.g. to
// build displayRepresentation).
struct NoteEntity: AppEntity {
    static let defaultQuery = NoteEntityQuery()
    var id: UUID
    @Property(title: "Title") var title: String
    @Property(title: "Tags")  var tagCount: Int
    var iconName: String       // fine as a plain `var`: only feeds displayRepresentation
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(title)") }
}
```

## `entities(for:)` and `suggestedEntities()` are different jobs — implement both

`EntityQuery` has two entry points that read as near-synonyms but serve opposite directions. `entities(for:)` is a *required* method: given identifiers the system already holds, return the matching entities. `suggestedEntities()` is what populates the picker when the system has *no* id yet and needs to offer choices. Crucially, `suggestedEntities()` has a **default implementation that returns empty** — so if you only implement `entities(for:)`, the query compiles and resolves saved values fine, yet the Shortcuts/Siri parameter picker shows an empty list and users can't choose anything.

```swift
// AVOID: implementing only entities(for:). Compiles, resolves persisted ids —
// but suggestedEntities() falls back to the framework default (empty), so the
// parameter picker is blank and the entity feels "unpickable."
struct NoteEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [NoteEntity] {
        try await store.notes(withIDs: identifiers)
    }
    // suggestedEntities() left to default → returns [] → empty picker
}
```

```swift
// PREFER: implement both. entities(for:) resolves known ids; suggestedEntities()
// supplies the initial choices the picker displays.
struct NoteEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [NoteEntity] {
        try await store.notes(withIDs: identifiers)
    }

    func suggestedEntities() async throws -> [NoteEntity] {
        try await store.recentNotes(limit: 20)
    }
}
```

If you want the picker to support free-text search (the user typing a name rather than picking from a list), conform to `EntityStringQuery` and implement `entities(matching:)`. That method is a bare protocol requirement with **no default and no framework-side filtering** — the system hands you the raw search string and your implementation must perform the match itself; there is no automatic "filter `suggestedEntities()` by substring" behavior to fall back on.

```swift
// PREFER: EntityStringQuery when the picker should search by name. You own the
// match — the framework does not filter for you.
struct NoteEntityQuery: EntityStringQuery {
    func entities(for identifiers: [UUID]) async throws -> [NoteEntity] {
        try await store.notes(withIDs: identifiers)
    }
    func entities(matching string: String) async throws -> [NoteEntity] {
        try await store.notes(titleContains: string)   // your query does the work
    }
    func suggestedEntities() async throws -> [NoteEntity] {
        try await store.recentNotes(limit: 20)
    }
}
```

## Resolve in one batch; keep suggestions cheap

`entities(for:)` takes an *array* of ids and returns an array by design — it is a batch resolve. The system may hand you many identifiers at once (a shortcut acting on a list of entities, a session referencing several). Treating it as "resolve one id" and looping a per-item fetch inside it turns one query into N round-trips (the classic N+1) — a per-id network or disk call per element. Issue a single query over the whole array instead. It's also valid to return *fewer* entities than requested: the framework silently drops ids with no match (and reorders your result to match the requested order), so an entity that no longer exists just gets omitted — you don't throw for it.

```swift
// AVOID: per-id fetch inside entities(for:). Ten selected notes = ten backend
// round-trips; the resolve is N× slower than it needs to be.
func entities(for identifiers: [UUID]) async throws -> [NoteEntity] {
    var result: [NoteEntity] = []
    for id in identifiers {
        result.append(try await store.note(withID: id))   // N round-trips
    }
    return result
}
```

```swift
// PREFER: one batched query over all ids. Missing ids are simply absent from
// the returned array — that's expected, not an error.
func entities(for identifiers: [UUID]) async throws -> [NoteEntity] {
    try await store.notes(withIDs: identifiers)            // single round-trip
}
```

`suggestedEntities()` sits at the other end of the cost model: the system calls it *opportunistically* to populate pickers, so it can fire when the user hasn't asked for anything expensive. Keep it cheap and bounded — return a recent/likely subset (e.g. a `limit:`), not your entire store — rather than doing heavy work or fetching everything on every invocation.

## `EnumerableEntityQuery` loads *everything* — the wrong query for a large store

`EnumerableEntityQuery` (iOS 17+) is the ergonomic query: implement `allEntities()` and the system auto-generates a Find action and filters for you. The catch is *how* it filters — it calls `allEntities()`, materializing your entire entity set in memory, then filters that. Fine for a small, bounded catalog (a fixed set of categories, a handful of accounts). For a store that grows to thousands of rows, or entities that are individually large, it's a memory/performance trap the compiler never flags.

```swift
// AVOID: EnumerableEntityQuery over an unbounded store. allEntities() loads every
// note into memory on every Find, then the framework filters in-memory.
struct NoteEntityQuery: EnumerableEntityQuery {
    func entities(for ids: [UUID]) async throws -> [NoteEntity] {
        try await store.notes(withIDs: ids)
    }
    func allEntities() async throws -> [NoteEntity] {
        try await store.allNotes()          // could be tens of thousands
    }
}
```

For a large or unbounded store, conform to `EntityPropertyQuery` instead: the system hands your data layer the query comparators, so you materialize only the matching entities rather than loading the whole set. Reserve `EnumerableEntityQuery` for small, bounded collections.
