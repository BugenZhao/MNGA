# `@Dependency` Registration and Placement

`@Dependency` looks like SwiftUI's `@Environment` — a value that "just appears" — but it is neither injected by a container you can see nor resolved by every type you might attach it to. It is a property wrapper backed by a single global registry (`AppDependencyManager.shared`), and it is only populated on types the framework knows how to prepare. It exists because the system instantiates your intents and queries itself (Siri, the Shortcuts app, Widgets), so there's no initializer of your own to inject through — the shared registry bridges that gap. Three facts break the naive mental model. Two are *runtime* traps: an *unregistered* dependency is a hard `fatalError`, and the wrapper is silently inert on types that don't support it (an `AppEntity`, an `AppEnum`) — both surface at runtime from Siri or an extension, never at compile time. The third bites at *compile* time: the dependency's value type must be `Sendable`.

## Register at launch, in `App.init()` — not lazily, not from a view

Accessing an unregistered `@Dependency` is a `fatalError` and not a catchable Swift error. There is no `try` that saves you: the crash happens inside the wrapper's `wrappedValue` getter the instant `perform()` (or a query) touches it. And intents run *cold*: Siri, Spotlight, an App Shortcut, or a background invocation can launch your app's process, construct the intent, and call `perform()` without your UI ever appearing. So any registration that runs "when the first view loads" or "on first user interaction" has not happened yet.

```swift
// AVOID: registering the dependency from view lifecycle. When the intent is
// invoked cold from Siri, ContentView never appears, so `add(...)` never runs —
// and the FIRST access of `database` inside perform() traps with
// "…was not initialized prior to access". It cannot be caught.
struct ContentView: View {
    var body: some View {
        NoteList()
            .onAppear {
                AppDependencyManager.shared.add(dependency: NoteDatabase.shared)
            }
    }
}

struct DeleteNoteIntent: AppIntent {
    static let title: LocalizedStringResource = "Delete Note"
    @Dependency var database: NoteDatabase   // traps if add(...) never ran

    @Parameter var note: NoteEntity
    func perform() async throws -> some IntentResult {
        try await database.delete(note.id)   // fatalError here on a cold launch
        return .result()
    }
}
```

```swift
// PREFER: register every dependency in App.init(), which runs on every process
// launch — including the cold, headless launches Siri/extensions trigger — before
// any intent or query can resolve it.
@main
struct NotesApp: App {
    init() {
        AppDependencyManager.shared.add(dependency: NoteDatabase.shared)
    }
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
```

Register from the earliest point that runs on *every* launch of the intent's host process — `App.init()` for an app, or the equivalent one-time setup in an extension that vends the intent. If a dependency genuinely may be absent, give the wrapper a `default:` (an `@Dependency` initializer overload) so resolution has a fallback instead of trapping; do not wrap the access in `do/catch` expecting to recover.

## Put `@Dependency` on the query/intent — never on the entity or enum

`@Dependency` is resolved only on types the framework prepares for it: `AppIntent`, `DynamicOptionsProvider`, and therefore `EntityQuery` (which refines `DynamicOptionsProvider`). `AppEntity` and `AppEnum` are *not* among them. A `@Dependency` stored on an `AppEntity` compiles (the wrapper is a normal property), but the framework never prepares it — it populates `@Dependency` only on the supported types above, never on entities. So a read on an entity is unreliable: it either traps like an unregistered dependency or returns a value only by coincidence, never something to rely on (a `default:` doesn't save it). The fix is placement, not registration: the entity's data access belongs in its `EntityQuery`, and that is where the dependency goes.

```swift
// AVOID: @Dependency stored on the entity. AppEntity does not support dependency
// resolution, so `database` is never prepared by the framework. This compiles and
// looks correct, then fails when touched — the framework never prepares it there,
// so the read is unreliable and a default: won't save it.
struct NoteEntity: AppEntity {
    @Dependency var database: NoteDatabase   // never populated — silently inert

    let id: UUID
    var title: String
    static var defaultQuery = NoteQuery()
    // …displayRepresentation, typeDisplayRepresentation…
}
```

```swift
// PREFER: put the @Dependency on the EntityQuery, which DOES support resolution.
// The query owns data access; the entity stays a plain value type.
struct NoteEntity: AppEntity {
    let id: UUID
    var title: String
    static var defaultQuery = NoteQuery()
    // …displayRepresentation, typeDisplayRepresentation…
}

struct NoteQuery: EntityQuery {
    @Dependency var database: NoteDatabase   // resolved: EntityQuery supports it

    func entities(for identifiers: [UUID]) async throws -> [NoteEntity] {
        try await database.notes(matching: identifiers)
    }
    func suggestedEntities() async throws -> [NoteEntity] {
        try await database.recentNotes()
    }
}
```

The same rule applies to an `AppEnum`: it has no dependency support, so any service it needs must be reached through the intent or the query that uses it, not stored on the enum. If an intent needs the dependency directly, declaring `@Dependency` on the `AppIntent` itself is correct — that is one of the supporting types. Don't try to force dependency support onto an entity or enum — the framework doesn't prepare those types for it; move the dependency to the query or intent instead.

## The dependency's value type must be `Sendable`

`@Dependency` is declared `AppDependency<Value: Sendable>`, and `AppDependencyManager.add(...)` takes a `Dependency: Sendable`. So the type you register and inject **must conform to `Sendable`** — because `AppIntent` and the query types are themselves `Sendable`, a non-`Sendable` stored `@Dependency` makes the enclosing intent/query ill-formed, with the diagnostic *"Stored property '_store' of 'Sendable'-conforming struct '…' contains non-Sendable type '…'."* The trap is that the natural candidate for a dependency — an `@Observable final class` model/store with mutable state — is **not** `Sendable` by default, so the obvious `@Dependency var store: BookStore` fails to compile.

```swift
// AVOID: injecting a non-Sendable store. `BookStore` is an @Observable class with
// mutable state and no Sendable conformance, so storing it as a @Dependency on a
// Sendable AppIntent is a Swift 6 error — "contains non-Sendable type 'BookStore'".
@Observable final class BookStore {        // not Sendable
    var books: [Book] = []
    var selectedBookID: UUID?
}

struct OpenBookIntent: OpenIntent {
    static let title: LocalizedStringResource = "Open Book"
    @Parameter var target: BookEntity
    @Dependency private var store: BookStore   // ❌ non-Sendable dependency

    @MainActor func perform() async throws -> some IntentResult {
        store.selectedBookID = target.id
        return .result()
    }
}
```

```swift
// PREFER: make the dependency Sendable. Isolate the store to the main actor
// (@MainActor implies Sendable for a reference type) so it's safe to hand across
// the concurrency boundary; the intent already hops to @MainActor to touch it.
@MainActor @Observable final class BookStore {   // @MainActor ⇒ Sendable
    var books: [Book] = []
    var selectedBookID: UUID?
}

struct OpenBookIntent: OpenIntent {
    static let title: LocalizedStringResource = "Open Book"
    @Parameter var target: BookEntity
    @Dependency private var store: BookStore   // ✓ Sendable now

    @MainActor func perform() async throws -> some IntentResult {
        store.selectedBookID = target.id
        return .result()
    }
}
```

Prefer isolating the type to `@MainActor` (correct for a UI-facing store an intent mutates) or making it an `actor`. Whatever you choose applies equally whether the `@Dependency` lives on the intent or on the `EntityQuery`.

