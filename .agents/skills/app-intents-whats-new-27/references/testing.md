# Testing App Intents with AppIntentsTesting

**SDK Version:** iOS 27.0 and later

`AppIntentsTesting` (`import AppIntentsTesting`; a developer-tools framework that links only from test targets) runs your app intents, entities, enums, and queries **out-of-process against your installed app — the same way Siri or Shortcuts invoke them** — and lets you assert on the results through type-erased wrappers, without linking your app target into the test. Because execution is out-of-process, you don't inject test doubles in the test process; you arrange deterministic data by driving the app itself (e.g. a seed intent), and assert against what its real queries and `perform()` return.

The examples use **XCTest** and are drawn from Apple's published **CometCal** calendar sample, which has `EventEntity` / `CalendarEntity` (both `IndexedEntity`), their string/enumerable queries, intents like `CreateEventIntent` / `OpenEventIntent` / `FetchEventIntent`, and debug-only seed intents (`SeedSampleEventsIntent`, `ResetTestDataIntent`).

The entire `AppIntentsTesting` module is `@available(iOS 27.0, macOS 27.0, watchOS 27.0, tvOS 27.0, visionOS 27.0)`; the simplest setup is a test target that deploys to iOS 27+ — see "Deployment target below SDK 27" if it deploys lower.

## A shared base test case

Hold one `IntentDefinitions(bundleIdentifier:)` (the bundle id of your app under test, **not** the test bundle) and expose per-type accessors — addressing intents/entities by their **type/intent name**. The subscripts (`.intents["…"]`, `.entities["…"]`, plus `.enums`, `.transientEntities`, `.valueQueries`) return the definition directly (non-optional). Arrange deterministic data in `setUp` by running the app's seed intent, so every test starts from known events:

```swift
import XCTest
import AppIntentsTesting

@available(iOS 27.0, macOS 27.0, watchOS 27.0, tvOS 27.0, visionOS 27.0, *)
class CalendarTestCase: XCTestCase {
    let app = XCUIApplication()
    let definitions = IntentDefinitions(bundleIdentifier: "com.example.CometCal")   // your app's bundle id

    var eventEntity: AppEntityDefinition { definitions.entities["EventEntity"] }
    var calendarEntity: AppEntityDefinition { definitions.entities["CalendarEntity"] }
    var createEvent: AppIntentDefinition { definitions.intents["CreateEventIntent"] }
    var openEvent: AppIntentDefinition { definitions.intents["OpenEventIntent"] }
    var seedSampleEvents: AppIntentDefinition { definitions.intents["SeedSampleEventsIntent"] }

    override func setUp() async throws {
        try await super.setUp()
        try await seedSampleEvents.makeIntent().run()   // out-of-process seed → known data
    }
}
```

`makeReference(identifier:)` / `makeIntent(…)` build a type-erased `AnyAppEntity` / `AnyAppIntent`; `makeIntent` is a callable wrapper (`IntentValuePropertiesCallable`), so you invoke it like a function and pass parameters by their **real `@Parameter` label**. A `makeReference(identifier:)` reference is non-throwing and carries the **id only** — the entity's other properties read as nil until the app resolves it through a query.

**Availability:** iOS 27.0, macOS 27.0, watchOS 27.0, tvOS 27.0, visionOS 27.0.

## Executing an intent and reading the result

`AnyAppIntent.run()` is `@discardableResult func run() async throws -> ResolvedIntentResult`; it runs the full resolve-then-`perform()` pipeline out-of-process. For an entity-returning intent, read a property off the result with the **throwing** `result.value` accessor (`try` required). Note `result.value` passed straight into another `makeIntent(…)` needs no `try` — in a parameter position the compiler selects a non-throwing overload of the `.value` lookup; only a *typed read* like `result.value.title` throws:

```swift
final class IntentExecutionTests: CalendarTestCase {
    func testCreateEventReturnsEntity() async throws {
        let result = try await createEvent.makeIntent(
            title: "Asteroid Dodgeball Practice",
            startDate: Date(),
            isAllDay: false,
            calendar: "Deep Space"
        ).run()
        XCTAssertEqual(try result.value.title, "Asteroid Dodgeball Practice")   // typed read → try
    }

    func testUpdateTakesTheReturnedEntity() async throws {
        let created = try await createEvent.makeIntent(
            title: "Temp Event", startDate: Date(), isAllDay: false, calendar: "Mission Control"
        ).run()
        let updated = try await definitions.intents["UpdateEventIntent"].makeIntent(
            event: created.value,                    // returned entity as a parameter — no `try`
            title: "Temp Event (Revised)"
        ).run()
        XCTAssertEqual(try updated.value.title, "Temp Event (Revised)")
    }
}
```

CometCal's intents return entities, but if an intent returns a scalar, another value, or an enum, read `result.value` (a throwing typed read) accordingly. `.as(_:)` lives on the value path you get from `result.value`, and an enum result comes back as `AnyAppEnum`:

```swift
// Primitive result — bind the expected type (Double / String / … conform to IntentValueConvertible):
let miles: Double = try result.value

// Convert the value path to another IntentValueConvertible type with .as(_:):
let name = try result.value.as(String.self)

// An enum result comes back as AnyAppEnum — read rawValue (or .as(_:) for a LosslessStringConvertible type):
let status: AnyAppEnum = try result.value
XCTAssertEqual(status.rawValue, "confirmed")
```

For a `perform()` that throws (CometCal's `FetchEventIntent` throws when no event matches), assert the error path with `do / try / XCTFail / catch` — XCTest has no async throw-assert, and confirmation is handled automatically (you don't supply a confirmation handler):

```swift
func testFetchMissingEventThrows() async {
    do {
        _ = try await definitions.intents["FetchEventIntent"].makeIntent(title: "No Such Event").run()
        XCTFail("Expected FetchEventIntent to throw when no event matches")
    } catch {
        // expected — the intent throws eventNotFound
    }
}
```

**Availability:** iOS 27.0, macOS 27.0, watchOS 27.0, tvOS 27.0, visionOS 27.0.

## Asserting entity queries

Exercise an entity's query through its `AppEntityDefinition`; the call dispatches to the app under test, so you assert against its seeded data. `AnyAppEntity` is `@dynamicMemberLookup` with **throwing** typed reads; its `identifier` is an `AttributedEntityIdentifier` (get the string id from `entity.identifier.instanceIdentifier`). The surfaces are `entities(matching:)` (string query), `entities(identifiers:)`, `allEntities()`, and `suggestedEntities()` — each returning `[AnyAppEntity]`, plus a `…Query()` variant returning `AnyEntityQuery`.

```swift
final class EntityQueryTests: CalendarTestCase {
    func testStringQueryMatchesSeededEvent() async throws {
        // "Cosmic Ray Calibration" is one of the seeded events.
        let results = try await eventEntity.entities(matching: "Cosmic Ray")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(try results[0].title, "Cosmic Ray Calibration")
    }

    func testAllAndSuggested() async throws {
        let all = try await eventEntity.allEntities()
        XCTAssertFalse(all.isEmpty)
        let suggested = try await eventEntity.suggestedEntities()
        XCTAssertFalse(suggested.isEmpty)
    }
}
```

**Availability:** iOS 27.0, macOS 27.0, watchOS 27.0, tvOS 27.0, visionOS 27.0.

## Value queries: values(for:)

`values(for:)` is the only `AppIntentsTesting` entry point for an `IntentValueQuery` — the query Visual Intelligence uses to turn a search input into candidate values (see `visual-intelligence.md` for authoring one). CometCal ships no `IntentValueQuery`, but the `valueQueries` registry tests one the moment your app exposes it. Suppose CometCal added an `EventValueQuery` returning events for a search input: reach it through `definitions.valueQueries["…"]`, call `values(for:)` with the input (in a test you pass a plain value such as a `String`, not a `SemanticContentDescriptor`), and read `result.items`. `items` is a `DynamicPropertyPathCollection` — not an array — so read a property off an item by binding the item as a `DynamicPropertyPath`, then a throwing typed read:

```swift
final class EventValueQueryTests: CalendarTestCase {
    func testValueQueryReturnsItems() async throws {
        // Illustrative: assumes CometCal exposes an EventValueQuery. "Cosmic Ray Calibration" is seeded.
        let result = try await definitions.valueQueries["EventValueQuery"].values(for: "Cosmic Ray")
        XCTAssertEqual(result.items.count, 1)

        let first: DynamicPropertyPath = result.items[0]        // element → path (non-throwing)
        XCTAssertEqual(try first.title, "Cosmic Ray Calibration")   // typed read → try

        let empty = try await definitions.valueQueries["EventValueQuery"].values(for: "nope")
        XCTAssertTrue(empty.items.isEmpty)
    }
}
```

**Availability:** iOS 27.0, macOS 27.0, watchOS 27.0, tvOS 27.0, visionOS 27.0.

## View annotations: viewAnnotations()

`viewAnnotations()` reports the entities the app annotates on the **currently visible screen** — the read-back side of the onscreen annotations the app authors with `.appEntityIdentifier(...)` / `NSUserActivity.appEntityIdentifier` (see `onscreen-entities.md`). So drive the real app UI with `XCUIApplication` (open the detail screen via an intent, wait for it to appear), then read them. `ViewAnnotation` exposes `isSelected: Bool` and `entity: AnyAppEntity`:

```swift
final class ViewAnnotationTests: CalendarTestCase {
    @MainActor
    func testEventDetailIsAnnotated() async throws {
        let events = try await eventEntity.entities(matching: "Crew Lunch at the Nebula Cafe")
        let event = try XCTUnwrap(events.first)

        try await openEvent.makeIntent(target: event).run()          // navigate the UI

        XCTAssertTrue(app.staticTexts["Crew Lunch at the Nebula Cafe"].waitForExistence(timeout: 5))

        let annotations = try await eventEntity.viewAnnotations()
        XCTAssertEqual(annotations.count, 1)
        let annotation = try XCTUnwrap(annotations.first)
        XCTAssertEqual(try annotation.entity.title, "Crew Lunch at the Nebula Cafe")
        XCTAssertTrue(annotation.isSelected)   // the detail screen selects the event it shows
    }
}
```

`ViewAnnotation.entity` is the annotated `AnyAppEntity` and `isSelected` reports whether the app marked that entity as the selected one on screen — a detail view that presents a single event annotates it as selected, as above. For a list screen, expect multiple annotations and assert on membership/count.

**Availability:** iOS 27.0, macOS 27.0, watchOS 27.0, tvOS 27.0, visionOS 27.0.

## Spotlight matching: spotlightQuery(_:)

`spotlightQuery(_:)` matches entities the app has indexed. Rather than indexing by hand, drive the app's normal flow — create the entity through an intent (`EventEntity` conforms to `IndexedEntity`, so the app indexes it as a side effect), give the index a moment to settle, then query:

```swift
final class SpotlightTests: CalendarTestCase {
    func testNewEventIsIndexed() async throws {
        let before = try await eventEntity.spotlightQuery("Supernova Viewing Party")
        XCTAssertTrue(before.isEmpty)

        _ = try await createEvent.makeIntent(
            title: "Supernova Viewing Party", startDate: Date(), isAllDay: false, calendar: "Deep Space"
        ).run()
        try await Task.sleep(for: .seconds(1))    // Spotlight indexing is asynchronous

        let hits = try await eventEntity.spotlightQuery("Supernova Viewing Party")
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(try hits[0].title, "Supernova Viewing Party")
    }
}
```

`spotlightQuery(_:)` is `@available(tvOS, unavailable)` / `@available(watchOS, unavailable)` — gate cross-platform files accordingly.

**Availability:** iOS 27.0, macOS 27.0, visionOS 27.0. Unavailable on tvOS and watchOS.

## Arranging deterministic data

Because everything runs **out-of-process against the installed app**, you can't inject test doubles or seed `AppDependencyManager.shared` from the test process — the intent resolves its `@Dependency` values inside the app, and `AppIntentsTesting` exposes no test-scoped injection API. Instead, drive the app to set up known state: CometCal ships debug-only **seed/reset intents** (`SeedSampleEventsIntent`, `ResetTestDataIntent`, `ClearSpotlightIntent`) that populate a known store, and the base case runs one in `setUp`. Then assert against those known values:

```swift
final class DataSeedingTests: CalendarTestCase {
    func testResetProducesKnownCalendars() async throws {
        try await definitions.intents["ResetTestDataIntent"].makeIntent().run()

        let calendars = try await calendarEntity.allEntities()
        let titles: [String] = try calendars.map { try $0.title }
        XCTAssertTrue(titles.contains("Mission Control"))
        XCTAssertTrue(titles.contains("Deep Space"))
    }
}
```

If your app has no such seed intent, add a debug-only one (as CometCal does) — it's the out-of-process equivalent of arranging a test fixture.

## Deployment target below SDK 27

`AppIntentsTesting` is entirely iOS 27.0+, and a test that drives it only runs on iOS 27 — so the simplest path is to make the test target deploy to iOS 27+, and nothing needs gating. If the test target deploys lower, two things matter: you **cannot** gate the `import` itself (`@available` isn't allowed on an `import`, and there is no compile-time `#if available`) — the `import` weak-links and compiles fine on older targets; instead gate the **usage** by putting `@available(iOS 27.0, …, *)` on the enclosing test case. An ungated reference then fails to compile with `'IntentDefinitions' is only available in iOS 27.0 or newer`.

```swift
import XCTest
import AppIntentsTesting

@available(iOS 27.0, macOS 27.0, watchOS 27.0, tvOS 27.0, visionOS 27.0, *)
final class GatedTests: XCTestCase {
    let definitions = IntentDefinitions(bundleIdentifier: "com.example.CometCal")   // your app's bundle id

    func testRunsUnderGate() async throws {
        let result = try await definitions.intents["CreateCalendarIntent"].makeIntent(
            name: "Occupy Saturn", color: "red"
        ).run()
        XCTAssertEqual(try result.value.title, "Occupy Saturn")
    }
}
```

For `spotlightQuery(_:)`, additionally carry `@available(tvOS, unavailable)` / `@available(watchOS, unavailable)`.

## Availability summary

| API | iOS | macOS | watchOS | tvOS | visionOS |
|---|---|---|---|---|---|
| `IntentDefinitions`, `makeIntent`, `makeReference(identifier:)` | 27 | 27 | 27 | 27 | 27 |
| `AnyAppIntent.run()` / `ResolvedIntentResult.value` | 27 | 27 | 27 | 27 | 27 |
| entity queries / `AnyEntityQuery` / `AnyAppEntity` (`AttributedEntityIdentifier`) | 27 | 27 | 27 | 27 | 27 |
| `valueQueries` / `values(for:)` / `.items` (`DynamicPropertyPathCollection`) | 27 | 27 | 27 | 27 | 27 |
| `viewAnnotations()` / `ViewAnnotation` | 27 | 27 | 27 | 27 | 27 |
| `spotlightQuery(_:)` | 27 | 27 | n/a | n/a | 27 |
