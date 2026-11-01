# `AppEnum` Persistence and Display

An `AppEnum` looks like an ordinary Swift enum, but two of its guarantees are enforced *outside* the compiler: how a value survives being saved into a shortcut, and whether it can be displayed at all. The declaration is `protocol AppEnum: AppValue, StaticDisplayRepresentable, RawRepresentable where RawValue: LosslessStringConvertible` — so it is `RawRepresentable`, and the framework persists the *raw value's string form*, not the case's position. Separately, `StaticDisplayRepresentable` requires a `caseDisplayRepresentations` dictionary that the framework indexes by case with no compiler check that every case is present. Both facts mean an edit that "compiles clean" can silently corrupt a saved shortcut or crash at display time. The two sections below cover each.

## Raw values are persisted by string — assign them explicitly and only ever append

When a shortcut is saved, an `AppEnum` value is serialized as `rawValue.description` — the string form of the raw value, chosen precisely because `LosslessStringConvertible` makes it round-trippable. Deserialization looks the case back up *by that string*. So the identity that persists across saves is the raw value's text, not the case name and not its declaration order. If you let Swift synthesize raw values (implicit `Int`, or `String` defaulting to the case name) and then reorder, rename, or renumber cases, previously-saved shortcuts silently rebind to whatever case now owns that string — a data-corruption bug with no diagnostic.

```swift
// AVOID: synthesized raw values that move when the source changes. These Ints
// are positional (small = 0, medium = 1, large = 2). Inserting `mini` at the
// top — or alphabetizing the cases — shifts every number. A shortcut a user
// saved as "large" (2) now deserializes as whatever case became 2. Silent.
enum DrinkSize: Int, AppEnum {
    case small
    case medium
    case large
    // later edit inserts `case mini` above `small`, or the cases get sorted…
}
```

```swift
// PREFER: explicit, stable raw values that never change once shipped, and only
// ever APPEND new cases. Reordering the source is now cosmetic — the persisted
// string ("small"/"medium"/"large") is pinned to its case regardless of position.
enum DrinkSize: String, AppEnum {
    case small = "small"
    case medium = "medium"
    case large = "large"
    case mini = "mini"      // appended later — safe; existing shortcuts unaffected

    // caseDisplayRepresentations required by AppEnum but omitted here for brevity —
    // see the next section (a missing entry is a runtime fatalError, not a build error).
}
```

Treat shipped raw values like a wire format: renaming a case's *display* text (in `caseDisplayRepresentations`) is fine and localizable, but the raw value is frozen. Deleting a case that older shortcuts may reference orphans those shortcuts. This is the same "identity is persisted, not position" discipline that `AppEntity`/`EntityIdentifier` requires — see `entities-and-queries.md`.

## Every case needs a `caseDisplayRepresentations` entry — a gap is a runtime crash, not a build error

`caseDisplayRepresentations` is `[Self: DisplayRepresentation]`, a plain dictionary — the compiler does not verify it is exhaustive over your cases. When the framework reads a case's title to display it and that case has no entry, it hits a `fatalError`. So adding a case and forgetting its dictionary entry compiles cleanly and then traps the moment that case is displayed (in the Shortcuts value picker, in a disambiguation prompt, anywhere its title is read).

```swift
// AVOID: a case with no dictionary entry. This compiles — the dictionary is not
// checked for exhaustiveness. When `mini` reaches any display path, the framework's
// unsafeDisplayRepresentation force-unwraps a nil lookup and fatalErrors.
enum DrinkSize: String, AppEnum {
    case small = "small"
    case medium = "medium"
    case large = "large"
    case mini = "mini"      // added to the enum…

    static let caseDisplayRepresentations: [DrinkSize: DisplayRepresentation] = [
        .small: "Small",
        .medium: "Medium",
        .large: "Large",
        // …but never added here. Crash at display time, not at build time.
    ]
}
```

```swift
// PREFER: one entry per case. When you append a raw value (section above), add
// its display representation in the same edit — the two changes are inseparable.
enum DrinkSize: String, AppEnum {
    case small = "small"
    case medium = "medium"
    case large = "large"
    case mini = "mini"

    static let caseDisplayRepresentations: [DrinkSize: DisplayRepresentation] = [
        .small: "Small",
        .medium: "Medium",
        .large: "Large",
        .mini: "Mini",      // added alongside the case
    ]
}
```

Because there is no compile-time safety net, make the dictionary edit part of the muscle memory of adding a case: new `case` + new raw value + new `caseDisplayRepresentations` entry, always in one change.
