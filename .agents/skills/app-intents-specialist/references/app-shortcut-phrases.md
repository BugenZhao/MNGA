# App Shortcut Phrases

An `AppShortcut` is the zero-configuration entry point to an intent: it ships in the app binary, and the phrases you attach are what a user speaks to Siri or sees in Spotlight without ever opening your app. Because the phrases and the intent identifiers are extracted at build time and indexed by the system, they behave like a **published contract**: once a phrase is installed on a device, renaming or removing it breaks existing voice invocations and the muscle memory built around them. (Automations and saved Shortcuts run the underlying *intent* by its identifier, a separate contract, so they survive a phrase change; it's the spoken phrase that breaks.) Add new phrases; do not silently rewrite or delete shipped ones. The traps below are the ones that don't announce themselves at the call site: a deprecated initializer that still compiles, and an application-name rule that Xcode warns about at build time and the runtime index enforces by dropping non-compliant phrases.

## Give every `AppShortcut` a `shortTitle` and `systemImageName`

`AppShortcut` has an initializer whose `shortTitle` and `systemImageName` are optional — and it is deprecated. The current supported initializer requires both as non-optional. If you omit them, you bind to the deprecated overload, and the App Shortcut has no short title or SF Symbol for the Shortcuts app, Spotlight, and the Action button to render. It compiles and "works," so the gap is invisible until a designer or reviewer notices the blank tile.

```swift
// AVOID: omitting shortTitle/systemImageName. This resolves to the initializer
// that is @available(..., deprecated: iOS 17.0, "Please provide a shortTitle and
// systemImageName"). The shortcut installs, but the system has nothing to draw
// for the tile, and you inherit a deprecation warning you may not read.
struct LibraryShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenLibraryIntent(),
            phrases: ["Open my library in \(.applicationName)"]
        )
    }
}
```

```swift
// PREFER: use the initializer that requires both. shortTitle is what Shortcuts and
// Spotlight display; systemImageName is the SF Symbol on the tile. systemImageName
// must be a compile-time string literal, not a variable or computed value.
struct LibraryShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenLibraryIntent(),
            phrases: ["Open my library in \(.applicationName)"],
            shortTitle: "Open Library",
            systemImageName: "books.vertical"
        )
    }
}
```

The `systemImageName` parameter must be a compile-time string literal — the SF Symbol name is fixed at build time and cannot be a variable or computed value. Choose a symbol that actually exists in SF Symbols; an unknown name renders nothing.

## Put `\(.applicationName)` in every phrase: Xcode warns, then the index drops it

Every App Shortcut phrase should include the `\(.applicationName)` token (the `.applicationName` case of `AppShortcutPhraseToken`, interpolated into the phrase string). At extraction time this token expands to the literal marker `${applicationName}`, which the system later fills with the app's localized name. Anchoring each phrase to the app name is how Siri disambiguates your shortcut from every other app's — a bare "Open my library" is ambiguous across apps and won't reliably route to yours.

If people know your app by more than one name, register synonyms so the app-name token still routes to your app: add an `INAlternativeAppNames` array to your Info.plist (each entry an `INAlternativeAppName`, optionally with a pronunciation hint; at most three per localization). To make one of those synonyms the name App Shortcuts prefer, add the `INPreferredForAppShortcuts` key to that entry. See Apple's [Specifying synonyms for your app name](https://developer.apple.com/documentation/sirikit/specifying-synonyms-for-your-app-name).

The non-obvious part: **the `AppShortcut` initializer never validates your phrases, but the build tooling and the runtime index do.** The initializer passes the phrase strings through untouched, so a phrase missing `\(.applicationName)` still type-checks. Xcode's App Shortcuts extraction, though, **emits a build warning** for a phrase that lacks the app-name token, so watch your build warnings. If you ship past it, the runtime index drops that phrase when it indexes your App Shortcuts (you may see a `Phrase missing \(.applicationName)` note in the device logs), and it never becomes a usable voice trigger.

```swift
// AVOID: a phrase with no application-name token. The initializer accepts it and
// it compiles (with a build warning), and if shipped the index drops it (logging
// "Phrase missing"), so this utterance never routes to your app at all.
AppShortcut(
    intent: PlayMixIntent(),
    phrases: ["Play my daily mix"],   // ambiguous across apps; no ${applicationName}
    shortTitle: "Daily Mix",
    systemImageName: "music.note"
)
```

```swift
// PREFER: interpolate the applicationName token so the phrase is unambiguously
// scoped to this app. Reference a parameter ONLY when it resolves to a finite,
// named set: an AppEnum, an AppEntity, or a Bool with true/false display names.
// Primitive types with no closed set of options CANNOT be referenced in a phrase.
AppShortcut(
    intent: PlayMixIntent(),
    phrases: [
        "Play my daily mix in \(.applicationName)",
        "Play \(\.$genre) in \(.applicationName)",   // genre is an AppEnum
    ],
    shortTitle: "Daily Mix",
    systemImageName: "music.note"
)
```

Two further constraints on parameter interpolation inside a phrase. First, only a parameter whose value resolves to a **finite, named set of options** is usefully referenceable: an `AppEnum` (the phrase expands across its cases, from each case's `caseDisplayRepresentations`), an `AppEntity` (across its query's dynamic options), or a `Bool` (expanded into `true`/`false` spoken variants). The `Bool` case carries an extra requirement that `AppEnum` does not: it produces variants only when the parameter supplies true/false display names via `@Parameter(..., displayName: Bool.IntentDisplayName(true: "On", false: "Off"))`. The parameter `title:` alone does not generate them, and without those two state names the system produces no variants. Interpolating a free-form `String`, number, or date parameter gives Siri no closed set to match against, so it isn't useful. 
Second, on quantity: an app may declare **at most 10 App Shortcuts**, and this is enforced at **build time** — `appintentsmetadataprocessor` fails the build (e.g. *"Found N App Shortcuts, but each app may have at most 10"*), so you can't ship over the cap. Keep the set focused and high-value, and avoid duplicate or semantically similar phrases.

Phrases carry a separate, **per-locale** budget, distinct from the App Shortcut count. The system caps the phrases it serves within a single locale (about 1,000 per locale, counted independently per locale rather than summed across them) and truncates beyond that. It counts *expanded* phrases: a template that interpolates an `AppEnum`/`AppEntity`/`Bool` expands into one phrase per option, so a handful of templates over large option sets can consume the budget quickly. You rarely need to approach it, because the system does flexible phrase matching, so don't enumerate minor wording variants as separate phrases; keep each phrase short and memorable, and note that piling on near-duplicate variations *degrades* Siri's match accuracy rather than widening coverage. To see how your phrases actually match, use Xcode's **Product > App Shortcuts Preview**.
## Refresh dynamic phrase parameters when the underlying options change

If a phrase interpolates an `AppEntity`/`AppEnum` parameter backed by dynamic options, the concrete option values (the "daily mix" names, the library entities) are snapshotted at extraction time into the phrase's substitution values. When your data changes — the user creates a new playlist, deletes an entity — the snapshot goes stale, and Siri keeps matching the old option set. `AppShortcutsProvider` exposes `updateAppShortcutParameters()` for exactly this: call it after the options change to make the system re-extract the current values.

```swift
// AVOID: never signaling that the option set changed. The phrase substitutions
// captured at build/extraction time are all Siri knows about, so a newly created
// playlist is unreachable by voice and a deleted one still matches.
func didCreatePlaylist(_ playlist: PlaylistEntity) async {
    try? await store.save(playlist)
    // ...and nothing tells App Intents the "play <playlist> in MyApp" options moved.
}
```

```swift
// PREFER: after the data behind a dynamic phrase parameter changes, ask the
// system to refresh the App Shortcut parameters so phrase expansion re-snapshots
// the current values.
func didCreatePlaylist(_ playlist: PlaylistEntity) async {
    try? await store.save(playlist)
    LibraryShortcuts.updateAppShortcutParameters()
}
```

This only matters for App Shortcuts whose phrases interpolate a parameter with *dynamic* options; a phrase referencing a static `AppEnum` (whose cases are fixed at compile time) has nothing to refresh.
