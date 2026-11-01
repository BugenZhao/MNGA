# Designing Errors Thrown from `perform()`

This file is about the *error* side of `perform()` — the `.result(...)` return shapes are covered in `execution-model.md`. The trap here is that throwing feels uniform ("throw an `Error`, the system shows it") but it is not. The framework inspects the *type* of what you throw. On Siri and Shortcuts a plain `Error` is presented to the user as a generic failure; conform to `CustomLocalizedStringResourceConvertible` to give the user a real message. The two subsections below cover the two correct ways to throw a user-meaningful failure: conform your own error type, or throw one of the framework's prebuilt errors.

## A bare `Error` gives the user a generic failure: conform to `CustomLocalizedStringResourceConvertible`

When `perform()` throws, the framework routes the error by type. If your error conforms to `CustomLocalizedStringResourceConvertible`, its `localizedStringResource` is serialized and delivered to Siri/Shortcuts as the failure message. Any other `Error` is sanitized and logged as an unknown error; on Siri and Shortcuts the user then sees a generic "something went wrong" rather than your `errorDescription` / `LocalizedError` text. `LocalizedError` is *not* the protocol the framework keys on here.

```swift
// AVOID: a plain Error (even a LocalizedError). Siri/Shortcuts show the user a
// generic failure, not "Playlist is full."
enum LibraryError: LocalizedError {
    case playlistFull
    var errorDescription: String? { "Playlist is full." }   // not shown by Siri/Shortcuts
}

func perform() async throws -> some IntentResult {
    guard playlist.hasRoom else { throw LibraryError.playlistFull }  // genericized
    // …
    return .result()
}
```

```swift
// PREFER: conform the error to CustomLocalizedStringResourceConvertible. The
// framework reads `localizedStringResource` and surfaces it verbatim.
enum LibraryError: Error, CustomLocalizedStringResourceConvertible {
    case playlistFull

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .playlistFull: "This playlist is full. Remove a song to add another."
        }
    }
}

func perform() async throws -> some IntentResult {
    guard playlist.hasRoom else { throw LibraryError.playlistFull }  // message preserved
    // …
    return .result()
}
```

Note the asymmetry with parameter resolution: `$param.needsValueError(_:)` and `AppIntentError.restartPerform` are flow control the framework *expects* (see `execution-model.md`), whereas a thrown application error is a terminal failure. Reserve conforming error types for genuine failures; don't reach for them to drive prompting.

## Use the prebuilt `AppIntentError` cases for standard failure shapes

For the common failure categories the system already knows how to present — a permission is missing, the user must take an action first, the operation cannot recover — throw one of the prebuilt `AppIntentError` static values instead of hand-writing a message. They come grouped under three enums: `AppIntentError.PermissionRequired`, `AppIntentError.UserActionRequired`, and `AppIntentError.Unrecoverable`. `AppIntentError` itself conforms to `CustomLocalizedStringResourceConvertible`, so these carry a localized message *and* a system-recognized category, which lets Siri respond appropriately (e.g. surfacing a sign-in affordance). These prebuilt categories — and `AppIntentError`'s `CustomLocalizedStringResourceConvertible` conformance — are available on iOS 18 / macOS 15 and later; the conform-your-own-error approach in the previous section works back to iOS 16.

```swift
// AVOID: a hand-rolled message for a category the system already models. You lose
// the system's built-in presentation/response for "needs sign-in," and you now own
// localization of a string the framework already ships.
enum LibraryError: Error, CustomLocalizedStringResourceConvertible {
    case notSignedIn
    var localizedStringResource: LocalizedStringResource { "You need to sign in." }
}

func perform() async throws -> some IntentResult {
    guard account.isSignedIn else { throw LibraryError.notSignedIn }
    return .result()
}
```

```swift
// PREFER: throw the prebuilt error for the category. Localized + system-recognized.
func perform() async throws -> some IntentResult {
    guard account.isSignedIn else {
        throw AppIntentError.UserActionRequired.signin
    }
    guard hasPhotoAccess else {
        throw AppIntentError.PermissionRequired.photos
    }
    guard let match = try await store.find(query) else {
        throw AppIntentError.Unrecoverable.entityNotFound
    }
    return .result()
}
```

Reach for a custom `CustomLocalizedStringResourceConvertible` error (the previous subsection) only when your failure is domain-specific and *isn't* one of the prebuilt categories. `AppIntentError.Unrecoverable.unknown` is deprecated — prefer a prebuilt case that names the actual failure, or a custom conforming error with a clear description, over the catch-all. The same type-based routing governs errors thrown from an `EntityQuery` method such as `entities(for:)`, not just `perform()`, so apply these rules wherever a user-visible failure escapes your intent code.

