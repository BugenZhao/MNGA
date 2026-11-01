# Cross-Device Entities & Ownership
**SDK Version:** iOS 27.0 and later

If the user's deployment target is below iOS 27 / macOS 27 / watchOS 27 / tvOS 27 / visionOS 27, the APIs in this reference (`SyncableEntity`, `SyncableEntityIdentifier`, `EntityOwnership`, and `OwnershipProvidingEntity`) require availability gating. All four are `anyAppleOS 27.0` and have no earlier back-deployment. See "Deployment target below SDK 27" below for the gating shape to use.

The same logical entity often lives on more than one of a person's devices — a landmark synced through CloudKit shows up on their iPhone, iPad, and Mac — and it may be private to them, shared into a collaborative plan, or shared publicly. The 2027 SDKs add `SyncableEntity` (with `SyncableEntityIdentifier`) so an entity keeps a stable identity as it moves between devices, and `OwnershipProvidingEntity` (with `EntityOwnership`) so the system can tell whether an entity is the person's own, shared, or public before acting on it. In the examples below, `LandmarkEntity` is a landmark synced across a person's devices and `TravelPhotoEntity` is a photo from a trip that the person may keep private, share into a group album, or share publicly.

## SyncableEntity

`SyncableEntity` refines `AppEntity` for an entity whose identity must survive travelling between a person's devices. A per-device local id (for example a SwiftData `persistentID`) is not enough: a shortcut created on iPhone must still resolve on iPad, where that local id was never minted. The protocol itself adds no requirements beyond `AppEntity`; its purpose is to pair the entity with a `SyncableEntityIdentifier` for its `ID`.

```swift
@available(iOS 27.0, *)
struct LandmarkEntity: SyncableEntity {
    // LocalID = the local store UUID; StableID = the CloudKit record name.
    let id: SyncableEntityIdentifier<UUID, String>

    @Property(title: "Name") var name: String

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Landmark")
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }

    static let defaultQuery = LandmarkEntityQuery()

    init(local: UUID, cloudKitID: String, name: String) {
        self.id = SyncableEntityIdentifier(local: local, stable: cloudKitID)
        self.name = name
    }
}
```

**Availability:** iOS 27.0, macOS 27.0, watchOS 27.0, tvOS 27.0, visionOS 27.0.

## SyncableEntityIdentifier

`SyncableEntityIdentifier<LocalID, StableID>` is the identifier a `SyncableEntity` uses for its `ID`. It carries an optional `local` id (a fast lookup key on the device that owns the local store) and an optional `stable` id (the cross-device key). Both `LocalID` and `StableID` must be `EntityIdentifierConvertible & Sendable`. The identifier is itself `Sendable`, `Equatable`, `Hashable`, `CustomStringConvertible`, and `EntityIdentifierConvertible`, so the framework can round-trip it through a string the way it does any entity id.

The designated initializer, `init(local:stable:)`, takes both keys as non-optional — you construct one when you hold both. The stored `local` and `stable` properties are optional because the framework can hand you back an identifier that has lost one side of the pair (for example an id round-tripped from a device that never saw the local store), so an `EntityQuery` must branch on whichever key survived.

```swift
@available(iOS 27.0, *)
struct LandmarkEntityQuery: EntityQuery {
    func entities(for identifiers: [LandmarkEntity.ID]) async throws -> [LandmarkEntity] {
        var results: [LandmarkEntity] = []
        for id in identifiers {
            if let local = id.local, let hit = try await ModelData.shared.landmark(localID: local) {
                results.append(LandmarkEntity(hit))          // fast path, same device
            } else if let stable = id.stable, let hit = try await ModelData.shared.landmark(cloudKitID: stable) {
                results.append(LandmarkEntity(hit))          // cross-device fallback
            }
        }
        return results
    }
}
```

When the local and stable ids are the same type and value, `init(id:)` is available where `LocalID == StableID`:

```swift
@available(iOS 27.0, *)
let sharedID = SyncableEntityIdentifier(id: recordName)   // LocalID == StableID == String
```

**Availability:** iOS 27.0, macOS 27.0, watchOS 27.0, tvOS 27.0, visionOS 27.0.

## EntityOwnership

`EntityOwnership` is an `OptionSet` (also `Sendable`) that describes how a person relates to an entity. It has three static members: `.unknown`, `.shared`, and `.public`. There is no `.private` or `.owned` case, and crucially **`.unknown` is the empty set** (`EntityOwnership.unknown == []`, rawValue 0): an entity that is neither shared nor public — *including the person's own* — has neither bit set, which is the same value as `.unknown`. You therefore cannot distinguish "owned" from "unknown." Because it is an `OptionSet`, you construct values with set-literal syntax and combine bits where an entity is genuinely more than one thing.

```swift
let ownedOrUnknown: EntityOwnership = []   // == .unknown (the framework's "unknown or unspecified"); also what you return for the person's own/private data
let shared: EntityOwnership = .shared      // the person shares it with specific collaborators
let published: EntityOwnership = .public   // the person shares this data publicly
```

Because `.unknown == []`, there is no separate "ownership is undetermined" value to return — don't write logic that tries to tell `.unknown` apart from an owned/empty set. Set the `.shared` and/or `.public` bits when they apply; leave the set empty (`[]`) otherwise.

**Availability:** iOS 27.0, macOS 27.0, watchOS 27.0, tvOS 27.0, visionOS 27.0.

## OwnershipProvidingEntity

`OwnershipProvidingEntity` refines `AppEntity` with a single requirement, `var ownership: EntityOwnership { get }`. Conform to it when an entity type spans private, shared, and public data, so the system knows the ownership of a given value before it acts on, surfaces, or forwards it. In particular, the system uses this to gate confirmation: acting on a `.shared` or `.public` entity can prompt the person to confirm — because the action reaches beyond their own data — where an owned entity would proceed without that extra step.

```swift
@available(iOS 27.0, *)
struct TravelPhotoEntity: OwnershipProvidingEntity {
    let id: UUID
    @Property(title: "Caption") var caption: String
    let source: PhotoSource   // .mine / .sharedWithMe / .sharedPublicly

    var ownership: EntityOwnership {
        switch source {
        case .mine:            return []          // own/private data — no shared/public bits
        case .sharedWithMe:    return .shared
        case .sharedPublicly:  return .public
        }
    }

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Travel Photo")
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(caption)") }
    static let defaultQuery = TravelPhotoQuery()
}
```

**Availability:** iOS 27.0, macOS 27.0, watchOS 27.0, tvOS 27.0, visionOS 27.0.

## Deployment target below SDK 27

When the user's deployment target is below SDK 27 and the answer needs any of the APIs above, gate every use with `@available(iOS 27.0, *)` (or the matching `anyAppleOS 27.0` platforms) on the enclosing declaration, and keep an entity that still works on older systems as the fallback:

```swift
@available(iOS 27.0, *)
struct LandmarkEntity: SyncableEntity {
    let id: SyncableEntityIdentifier<UUID, String>
    // …
}

// Fallback for deployment targets below iOS 27: a plain AppEntity keyed on the local id.
struct LegacyLandmarkEntity: AppEntity {
    let id: UUID
    // …
}
```

Guard runtime paths that read `ownership` or construct a `SyncableEntityIdentifier` with `if #available(iOS 27.0, *)`. Don't emit unconditional calls to these APIs; the typecheck will fail with `'<API>' is only available in iOS 27.0 or newer`.
