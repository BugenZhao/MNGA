# URL Representation & Opening

Three different mechanisms open content, and they are not interchangeable. `OpenIntent` is a marker protocol that names a `target` for the system to open. `OpenURLIntent` is a built-in intent that hands a `URL` to your app's universal-link handler. `URLRepresentableIntent`/`URLRepresentableEntity`/`URLRepresentableEnum` map a type *to* a universal link so the system opens it without running your `perform()` at all. Picking the wrong one — or writing a `perform()` that fights the URL machinery, or letting the URL mapping drift — are the recurring traps. `OpenIntent` is iOS 16+; everything URL-representable (including `OpenURLIntent`) is iOS 18+.

## `OpenIntent` supplies a `target` — don't hand-roll the foregrounding

`OpenIntent` is a marker protocol: it adds one requirement, `var target: Value { get set }`, and the system opens whatever that property holds (an `AppEntity` or `AppEnum`). Adopting it makes `openAppWhenRun` default to `true`, so the app is brought to the foreground for you; the protocol also supplies a default `perform()` that just returns `.result()`. Reimplementing the foregrounding yourself — a plain `AppIntent` with a URL parameter and an ad-hoc open in `perform()` — throws away the marker the system keys off of, and the naming/discovery benefits that come with it.

```swift
// AVOID: a plain AppIntent faking "open" behavior. Nothing marks this as an
// open intent, so Spotlight/Shortcuts can't populate a target, and you're
// manually reaching into app state to foreground — off-actor, in perform().
struct ShowNoteIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Note"
    @Parameter var note: NoteEntity

    func perform() async throws -> some IntentResult {
        AppState.shared.present(note)   // hand-rolled foregrounding
        return .result()
    }
}
```

```swift
// PREFER: conform to OpenIntent and expose `target`. openAppWhenRun becomes
// true automatically; the system foregrounds the app and hands you the item.
struct ShowNoteIntent: OpenIntent {
    static let title: LocalizedStringResource = "Show Note"
    @Parameter var target: NoteEntity

    func perform() async throws -> some IntentResult {
        await MainActor.run { AppState.shared.present(target) }
        return .result()
    }
}
```

`OpenIntent` refines `SystemIntent`, which refines `AppIntent` — it is an ordinary intent with one extra property, not a separate execution path. The `perform()` body still runs under the actor rules in `execution-model.md`: it is not `@MainActor`, so hop explicitly before touching UI state.

## Return `OpenURLIntent` for a URL — don't open URLs off your own bat

`OpenURLIntent` is the built-in intent for opening a universal link. Construct it with a `URL` (`OpenURLIntent(url)`), or from a URL-representable enum/entity via its throwing initializers, and *return* it as the result of another intent's `perform()` through the `OpensIntent` marker. It is also the intent you attach to a widget or Live Activity button to deep-link into your app. It is not a place to call your own URL-opening API from inside `perform()` — doing so bypasses the system's foregrounding and result plumbing.

```swift
// AVOID: opening a URL by side effect inside perform(). There's no opener API
// available to an intent that may run in an extension, and even where one
// exists this races the actor and returns nothing the system can chain on.
func perform() async throws -> some IntentResult {
    let url = URL(string: "https://example.com/notes/\(note.id)")!
    UIApplication.shared.open(url)   // wrong layer; off-actor; not returnable
    return .result()
}
```

```swift
// PREFER: return an OpenURLIntent through the .result(opensIntent:) factory.
// The system foregrounds the app and drives the URL into your universal-link
// handler for you.
func perform() async throws -> some OpensIntent {
    let url = URL(string: "https://example.com/notes/\(note.id)")!
    return .result(opensIntent: OpenURLIntent(url))
}
```

The two entity/enum initializers are `throws`/`async throws` and raise when the value has no valid URL representation — call them with `try`/`try await`, don't force-unwrap around them.

## Adopt `URLRepresentableIntent` and leave `perform()` alone

If your intent already maps cleanly to a universal link, conform to `URLRepresentableIntent` and provide `static var urlRepresentation: URLRepresentation`. The protocol supplies `perform()` for you (it opens the URL and never returns normally), and — critically — combining it with `OpenIntent` flips `openAppWhenRun` to `false` and routes the open entirely through your URL handler. Writing your own `perform()` body next to a URL representation is the trap: the system opens the URL via the URL path, so any work you put in `perform()` either never runs or runs redundantly. The doc guidance is explicit — when a URL is present, `perform()` should do nothing.

```swift
// AVOID: a URL representation AND a hand-written perform() that does real work.
// When a URL representation exists the system opens via the URL, so this body
// is dead code at best and a double-open at worst.
struct OpenPageIntent: URLRepresentableIntent {
    static let title: LocalizedStringResource = "Open Page"
    static var urlRepresentation: URLRepresentation = "https://example.com/\(\.$page)"

    @Parameter(title: "Page") var page: String

    func perform() async throws -> some IntentResult {
        try await Router.shared.navigate(to: page)   // won't run via URL path
        return .result()
    }
}
```

```swift
// PREFER: declare only the URL representation. The default perform() from the
// protocol handles opening; your universal-link code is the single entry point.
struct OpenPageIntent: URLRepresentableIntent {
    static let title: LocalizedStringResource = "Open Page"
    static var urlRepresentation: URLRepresentation = "https://example.com/\(\.$page)"

    @Parameter(title: "Page") var page: String
}
```

This protocol requires real universal-link support (`applinks:` associated domains) — it explicitly does *not* work with custom URL schemes. If you only have a custom scheme, this is the wrong tool; use an `OpenIntent` with a `perform()` that navigates instead.

## Build the URL by interpolating parameter *key paths*, not values

`URLRepresentation` is `IntentURLRepresentation<Self>` (and `EntityURLRepresentation<Self>` / `EnumURLRepresentation<Self>` for entities/enums), an `ExpressibleByStringInterpolation` builder. Its interpolation segment does not accept a value — it accepts a **key path to the parameter** (`\(\.$page)` for an intent parameter, `\(\.$contentID)` for an entity property). The builder records the key path and substitutes the resolved value when the URL is produced. Interpolating a plain expression (or the property's current value) is the subtle failure: it either won't type-check against the key-path overload or bakes in a stale value instead of a live placeholder.

```swift
// AVOID: interpolating a value or a bare property instead of the key path. This
// does not match the key-path interpolation the builder expects; it captures a
// snapshot rather than a placeholder the system fills at resolution time.
static var urlRepresentation: URLRepresentation = "https://example.com/\(page)"
```

```swift
// PREFER: interpolate the key path to the projected parameter. For an intent
// use \(\.$param); for an entity use \(\.$property). The builder substitutes
// the resolved value when it forms the URL.
static var urlRepresentation: URLRepresentation = "https://example.com/\(\.$page)"
```

Only URL-friendly parameter types substitute automatically — `String`, `Int`, and `URL`. For any other type, conform it to `CustomURLRepresentationParameterConvertible` and return a URL-safe string from `urlRepresentationParameter`; otherwise the segment resolves to empty. For an `AppEnum`, `EnumURLRepresentation` interpolates the *case* (`\(.rawValue)` or a specific case) rather than a key path, and takes a `[Enum: EnumSingleURLRepresentation]` dictionary overload when cases need distinct URLs — reach for the dictionary instead of branching inside a single format string.

## Treat the URL mapping as a stable contract, like ids and phrases

A `urlRepresentation` is a promise about how your content is addressed: existing widgets, Live Activities, shared links, and Spotlight results embed URLs built from today's format. Changing the path shape, renaming an interpolated parameter, or dropping a segment silently breaks every already-minted link — the same durability rule that governs entity `id`s and `AppShortcut` phrases. Evolve the mapping additively; keep old URLs resolvable.

```swift
// AVOID: restructuring the URL format in place. Every link already handed to a
// widget, share sheet, or Spotlight result was built on the old shape and now
// 404s in your universal-link handler.
static var urlRepresentation: URLRepresentation = "https://example.com/v2/item/\(\.$id)"
// was: "https://example.com/notes/\(\.$id)"
```

```swift
// PREFER: keep the established path stable so old links keep resolving; layer
// new capability behind additional parameters or new routes your handler also
// understands, rather than rewriting the contract.
static var urlRepresentation: URLRepresentation = "https://example.com/notes/\(\.$id)"
```

The same discipline applies to `URLRepresentableEntity` — its `urlRepresentationParameter` defaults to the entity's identifier string, so the id and the URL are one contract. Keep the entity id stable (see `entities-and-queries.md`) and the URL stays stable with it.
