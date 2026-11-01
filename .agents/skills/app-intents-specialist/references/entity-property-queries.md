# Property-Based Entity Queries

`EntityQuery` resolves entities by `id` and suggests defaults (see `entities-and-queries.md`). `EntityPropertyQuery` refines it with the next tier up: "find every X *where* some property compares a certain way," sorted and limited. This is what powers the Shortcuts **Find** action — the user builds a filter like "Notes where Title contains 'trip', sorted by date, limit 10," and your query has to answer it. The shape is unusual: you declare *which* properties are queryable and *which* comparators each supports, the framework parses the user's filter into that vocabulary, and then hands you the parsed predicate to execute against your own backend. The framework does not filter for you. This file covers that contract and its traps; it assumes the entity/`@Property`/id material from `entities-and-queries.md`.

## Declare the queryable surface with `properties` and `sortingOptions`

`EntityPropertyQuery` adds two required statics beyond `EntityQuery`: `static var properties: QueryProperties` lists each queryable property and the comparators it supports, and `static var sortingOptions: SortingOptions` lists the properties the user may sort by. Both are result builders. Every keypath is the `$`-projected form (`\.$title`) — the builder needs the `@Property` wrapper, not the underlying value, so a plain-value keypath (`\.title`) fails to compile, and a member that isn't `@Property`-wrapped at all has no `$` projection to reference (that's the `@Property` requirement from `entities-and-queries.md`, now load-bearing at the query layer).

```swift
// AVOID: conforming to EntityPropertyQuery but only carrying over the EntityQuery
// methods. `properties` and `sortingOptions` are required statics with no default
// — this does not compile, and even a `QueryProperties {}` stub with no Property
// entries yields a Find action the user can't filter with at all.
struct NoteQuery: EntityPropertyQuery {
    func entities(for ids: [UUID]) async throws -> [NoteEntity] {
        try await store.notes(withIDs: ids)
    }
    // ❌ no `properties`, no `sortingOptions`, no entities(matching:…)
}
```

```swift
// PREFER: declare the queryable properties with their comparators, and the
// sortable properties. Each comparator's closure maps the user's value into a
// ComparatorMappingType of YOUR choosing (here a predicate struct your store
// understands) — the framework never touches your backend, only this mapping.
struct NoteQuery: EntityPropertyQuery {
    typealias ComparatorMappingType = NotePredicate   // your own type

    static var properties = QueryProperties {
        Property(\.$title) {
            EqualToComparator    { NotePredicate.titleEquals($0) }
            ContainsComparator   { NotePredicate.titleContains($0) }
            HasPrefixComparator  { NotePredicate.titleHasPrefix($0) }
        }
        Property(\.$createdAt) {
            LessThanComparator    { NotePredicate.createdBefore($0) }
            GreaterThanComparator { NotePredicate.createdAfter($0) }
        }
    }

    static var sortingOptions = SortingOptions {
        SortableBy(\.$title)
        SortableBy(\.$createdAt)
    }

    func entities(for ids: [UUID]) async throws -> [NoteEntity] {
        try await store.notes(withIDs: ids)
    }
}
```

## The comparator must fit the property's type

The comparator classes are typed against the property. Equality ones (`EqualToComparator`, `NotEqualToComparator`) need an `Equatable` property; the ordered ones (`GreaterThanComparator`, `GreaterThanOrEqualToComparator`, `LessThanComparator`, `LessThanOrEqualToComparator`) need `Comparable`; `ContainsComparator` needs a `String`/`AttributedString` (substring) or a collection (element membership); `HasPrefixComparator`/`HasSuffixComparator` are `String`-only. `IsBetweenComparator` takes two inputs and is only surfaced for `Date` in Shortcuts. Attaching a comparator a property's type can't satisfy is a compile error, not a silent no-op — but the failure reads as an opaque generic-constraint mismatch, so it's worth getting right up front.

```swift
// AVOID: a comparator the property type doesn't support. `tagCount` is an Int, so
// HasPrefixComparator (String-only) can't apply; `title` is a String, so ordering
// comparators are meaningless on it. Both surface as confusing generic errors.
static var properties = QueryProperties {
    Property(\.$tagCount) {
        HasPrefixComparator { NotePredicate.bogus($0) }   // ❌ Int has no prefix
    }
    Property(\.$title) {
        GreaterThanComparator { NotePredicate.bogus($0) } // ❌ String isn't the ordered case you want
    }
}
```

```swift
// PREFER: match the comparator family to the type. Numeric/comparable → ordered
// comparators; String → contains/prefix/suffix; array → Contains for membership.
static var properties = QueryProperties {
    Property(\.$tagCount) {
        EqualToComparator     { NotePredicate.tagCountEquals($0) }
        GreaterThanComparator { NotePredicate.tagCountAbove($0) }
    }
    Property(\.$title) {
        ContainsComparator  { NotePredicate.titleContains($0) }
        HasPrefixComparator { NotePredicate.titleHasPrefix($0) }
    }
    Property(\.$tags) {   // [String]
        ContainsComparator { NotePredicate.hasTag($0) }   // element membership
    }
}
```

## You execute the predicate — the framework only parses it

The signature is `func entities(matching comparators: [ComparatorMappingType], mode: ComparatorMode, sortedBy: [Sort<Entity>], limit: Int?)`. Every argument is a *parsed instruction you must carry out*, not a filter the framework already applied. `comparators` is the array of values your mapping closures produced; `mode` is `.and` or `.or` (combine the comparators with all-must-match vs. any-match); each `Sort<Entity>` exposes `.by` (a `PartialKeyPath<Entity>`) and `.order` (`.ascending`/`.descending`); `limit` caps the count. Returning your whole store, or ignoring `mode`/`sortedBy`/`limit`, means the Find action returns wrong results — the framework will not re-filter or re-sort behind you.

```swift
// AVOID: ignoring the parsed query. Returning everything (or filtering but
// dropping mode/sort/limit) makes "Notes where title contains X, newest first,
// max 5" return every note in arbitrary order — the predicate was handed to you
// and silently discarded.
func entities(
    matching comparators: [NotePredicate],
    mode: ComparatorMode,
    sortedBy: [Sort<NoteEntity>],
    limit: Int?
) async throws -> [NoteEntity] {
    try await store.allNotes()   // ❌ comparators, mode, sortedBy, limit all ignored
}
```

```swift
// PREFER: translate the parsed query into your backend's own query and let the
// data layer do the filtering/sorting/limiting. Push the predicate down; honor
// mode, sort order, and limit. (Sort<Entity>.by is a PartialKeyPath you read to
// pick the column; .order gives ascending/descending.)
func entities(
    matching comparators: [NotePredicate],
    mode: ComparatorMode,
    sortedBy: [Sort<NoteEntity>],
    limit: Int?
) async throws -> [NoteEntity] {
    try await store.fetchNotes(
        predicates: comparators,
        combine: (mode == .and) ? .all : .any,
        sort: sortedBy,          // read .by / .order per element
        limit: limit
    )
}
```

## Reach for `EntityPropertyQuery` over `EnumerableEntityQuery` when the store is large

`EnumerableEntityQuery` (covered in `entities-and-queries.md`) is the load-everything tier: you implement `allEntities()`, the framework materializes the full set and filters it in memory. That's fine for a small bounded catalog, but for a store of thousands of rows it's the wrong shape — you pay to load the entire set on every Find. `EntityPropertyQuery` is the server-side-predicate alternative: because the framework hands you the parsed comparators, sort, and limit, you can turn them into a bounded database/network query and materialize only the matches. Choose by store size, not by which is easier to type: `EnumerableEntityQuery` for small fixed collections, `EntityPropertyQuery` once the data could grow unbounded or the rows are individually heavy.

```swift
// AVOID: EnumerableEntityQuery over an unbounded store. allEntities() loads every
// note into memory on each Find, then the framework filters in-memory — a
// memory/latency trap that grows with the store and never gets flagged.
struct NoteQuery: EnumerableEntityQuery {
    func entities(for ids: [UUID]) async throws -> [NoteEntity] {
        try await store.notes(withIDs: ids)
    }
    func allEntities() async throws -> [NoteEntity] {
        try await store.allNotes()          // ❌ could be tens of thousands
    }
}
```

```swift
// PREFER: EntityPropertyQuery, so the filter reaches your data layer and only the
// matching rows are fetched. Same Find action for the user; bounded cost for you.
struct NoteQuery: EntityPropertyQuery {
    typealias ComparatorMappingType = NotePredicate
    static var properties = QueryProperties {
        Property(\.$title) { ContainsComparator { NotePredicate.titleContains($0) } }
    }
    static var sortingOptions = SortingOptions { SortableBy(\.$createdAt) }

    func entities(for ids: [UUID]) async throws -> [NoteEntity] {
        try await store.notes(withIDs: ids)
    }
    func entities(
        matching comparators: [NotePredicate],
        mode: ComparatorMode,
        sortedBy: [Sort<NoteEntity>],
        limit: Int?
    ) async throws -> [NoteEntity] {
        try await store.fetchNotes(predicates: comparators, sort: sortedBy, limit: limit)
    }
}
```
