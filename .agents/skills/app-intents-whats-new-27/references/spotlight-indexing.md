# Spotlight Indexing Enhancements
**SDK Version:** iOS 26.0 and later

If the user's deployment target is below iOS 26 / macOS 26 / visionOS 26 (or iOS 27 / macOS 27 / visionOS 27 for the query and cross-link APIs), the new APIs in this reference (`@ComputedProperty(indexingKey:)` and `@DeferredProperty(indexingKey:)`, `IndexedEntityQuery` with `reindexEntities(for:indexDescription:)` / `reindexAllEntities(indexDescription:)`, and `CSSearchableItem.relatedAppEntityIdentifier` / `CSSearchableItemAttributeSet.relatedAppEntityIdentifier`) require availability gating. The baseline `IndexedEntity` conformance and `indexAppEntities`/`deleteAppEntities` are older (iOS 18) and are noted here only for context. See "Deployment target below SDK 27" below for the gating shape to use.

`IndexedEntity` (iOS 18.0) already lets an `AppEntity` project itself into a `CSSearchableItemAttributeSet` so it appears in Spotlight, and `CSSearchableIndex.indexAppEntities(_:priority:)` / `deleteAppEntities(...)` (also iOS 18.0) push and remove those entities. This reference covers what is *new* on top of that baseline: computed and deferred property indexing keys (iOS 26), a query protocol that lets the system drive reindexing (iOS 27), and a way to cross-link an independently indexed searchable item back to an app entity (iOS 27). Running example: a travel app, **TravelTracking**, whose library entity is `LandmarkEntity: IndexedEntity`.

These surfaces attach to *any* `IndexedEntity` — including a **schema-conforming** one, since a schema entity is still an `AppEntity`. CometCal's calendar entity combines both (`@AppEntity(schema: .calendar.event) struct EventEntity: IndexedEntity`), and a music library's `@AppEntity(schema: .audio.song)` entity is pushed to Spotlight the same way (`CSSearchableIndex.indexAppEntities([song])`). Schema adoption and Spotlight indexing are orthogonal — an entity can do both.

## Computed and deferred indexing keys

`@ComputedProperty(indexingKey:)` and `@DeferredProperty(indexingKey:)` map an entity value to a `CSSearchableItemAttributeSet` key path without stored backing, extending the older `@Property(indexingKey:)` (iOS 18.4) to derived values. Use `@ComputedProperty(indexingKey:)` when the value is computed synchronously from other fields, and `@DeferredProperty(indexingKey:)` when producing it is expensive or `async` (network, disk, decode) so it is fetched lazily rather than on every materialization. The key is a `PartialKeyPath<CSSearchableItemAttributeSet>`; both macros also offer a `title:`-prefixed overload. `@ComputedProperty` additionally has a `customIndexingKey:` overload taking a `CSCustomAttributeKey`; `@DeferredProperty` does not.

```swift
@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
struct LandmarkEntity: AppEntity, IndexedEntity {
    let id: UUID

    // Synchronous, derived from other fields.
    @ComputedProperty(indexingKey: \.title)
    var name: String { "\(number). \(rawName)" }

    // Expensive / async: fetched lazily, only when indexing needs it.
    @DeferredProperty(indexingKey: \.textContent)
    var notes: String { get async throws { try await ModelData.notes(for: id) } }
    // ...
}
```

**Availability:** `@ComputedProperty(indexingKey:)` / `(title:indexingKey:)` / `(customIndexingKey:)` and `@DeferredProperty(indexingKey:)` / `(title:indexingKey:)` are iOS 26.0, macOS 26.0, visionOS 26.0 (no watchOS/tvOS). The baseline `@Property(indexingKey:)` / `(title:indexingKey:)` is iOS 18.4, macOS 15.4, visionOS 2.4, and is `@available(watchOS, unavailable)` / `@available(tvOS, unavailable)`.

## System-driven reindexing from the query

`IndexedEntityQuery` refines `EntityQuery` (requiring `Self.Entity: IndexedEntity`) and adds `reindexEntities(for:indexDescription:)` and `reindexAllEntities(indexDescription:)`, letting the system ask your query to refresh Spotlight when the backing store changes. Both receive a `CSSearchableIndexDescription` and typically re-push entities through `CSSearchableIndex.indexAppEntities(_:)`.

```swift
@available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
struct LandmarkEntityQuery: IndexedEntityQuery {
    func entities(for identifiers: [LandmarkEntity.ID]) async throws -> [LandmarkEntity] {
        try await ModelData.landmarks(ids: identifiers)
    }

    func reindexEntities(
        for identifiers: [LandmarkEntity.ID],
        indexDescription: CSSearchableIndexDescription
    ) async throws {
        try await CSSearchableIndex.default().indexAppEntities(entities(for: identifiers))
    }

    func reindexAllEntities(
        indexDescription: CSSearchableIndexDescription
    ) async throws {
        try await CSSearchableIndex.default().indexAppEntities(ModelData.all())
    }
}
```

**Availability:** iOS 27.0, macOS 27.0, visionOS 27.0 (no watchOS/tvOS).

## Cross-link a searchable item to an app entity

`relatedAppEntityIdentifier` is a settable `EntityIdentifier?` on both `CSSearchableItem` and `CSSearchableItemAttributeSet`. Set it on an item you index directly (content *not* built from an `IndexedEntity`) to associate it with an existing app entity, so Spotlight's own UI can cross-link the two. This is distinct from the older iOS 18.0 `CSSearchableItem(appEntity:)` / `associateAppEntity(_:priority:)`, which build an item *from* an entity; `relatedAppEntityIdentifier` points an *independently* indexed item *at* an entity by identifier.

```swift
@available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
func indexRoutePage(for landmark: LandmarkEntity, html: URL) async throws {
    let item = CSSearchableItem(
        uniqueIdentifier: "route-\(landmark.id.uuidString)",
        domainIdentifier: "routes",
        attributeSet: CSSearchableItemAttributeSet(contentType: .html))
    item.relatedAppEntityIdentifier = EntityIdentifier(for: landmark)
    try await CSSearchableIndex.default().indexSearchableItems([item])
}
```

**Availability:** iOS 27.0, macOS 27.0, visionOS 27.0 (no watchOS/tvOS) on both `CSSearchableItem` and `CSSearchableItemAttributeSet`.

## Deployment target below SDK 27

When the user's deployment target is below the version an API requires, gate the new surface behind `@available`/`if #available` and keep a fallback that uses the baseline iOS 18 indexing path (a plain `@Property(indexingKey:)` and manual `indexAppEntities`), or skip the enhancement on older OS versions:

```swift
if #available(iOS 27, macOS 27, visionOS 27, *) {
    item.relatedAppEntityIdentifier = EntityIdentifier(for: landmark)   // iOS 27 API
}
try await CSSearchableIndex.default().indexSearchableItems([item])   // iOS 18 baseline
```

Gate the property macros at iOS 26 (`@ComputedProperty`/`@DeferredProperty(indexingKey:)`), and the query protocol and `relatedAppEntityIdentifier` at iOS 27, either with `if #available` around the use or `@available(iOS 26, *)` / `@available(iOS 27, *)` on an enclosing declaration. Do not emit these APIs on watchOS or tvOS — the property indexing keys, `IndexedEntityQuery`, and `relatedAppEntityIdentifier` are unavailable there at every OS version; branch to a plain property or skip indexing on those platforms. Don't emit unconditional calls; the typecheck will fail with `'<API>' is only available in iOS 26.0 or newer` (or 27.0).
