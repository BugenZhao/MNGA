# Onscreen Entities
**SDK Version:** iOS 18.2 and later

If the user's deployment target is below the availability listed for a given API in this reference (`NSUserActivity.appEntityIdentifier` / `AppEntityAnnotatable` are iOS 18.2; `EntityIdentifier(for:identifier:)` back-deploys to iOS 16.0, `EntityIdentifier(activityIdentifier:)` is iOS 18.0; the SwiftUI `.appEntityIdentifier(_:)` / `.appEntityIdentifier(forSelectionType:_:)` modifiers and `AppEntityUIElement` / `AppEntityUIElementsContext` are iOS 18.4), the usage requires availability gating. 

Onscreen entities let Siri and Apple Intelligence resolve "this" on the current screen to a concrete `AppEntity` — so a request like "add this to my list" binds to the entity the person is looking at. You do it by annotating the foreground `NSUserActivity` with the identifier of the entity being shown. This is a different surface from **visual-intelligence search** (matching camera/screenshot content — see `visual-intelligence.md`) and from **proactively surfacing** entities (`RelevantEntities` / `AppEntityContext` — see `relevance-and-context.md`). The running example is **CometCal, **a calendar app whose `EventEntity` is an `IndexedEntity` with `var id: UUID` and `var title: String`.

## Annotate NSUserActivity with the onscreen entity

For Siri or Apple Intelligence to resolve "this" while a detail screen is up, the foreground `NSUserActivity` must carry the identifier of the entity being shown. `NSUserActivity` conforms to `AppEntityAnnotatable`, which adds `var appEntityIdentifier: EntityIdentifier? { get set }`. Build the identifier with `EntityIdentifier(for:identifier:)` from the entity's type and id, and keep it in sync as the displayed entity changes.

In SwiftUI, the `.userActivity(_:element:_:)` modifier both keeps the activity current for the view and gives you a closure to populate it. CometCal's `EventDetailView` annotates the activity with the event being shown:

```swift
import AppIntents
import SwiftUI

// EventDetailView body, trailing modifiers
.userActivity("com.example.cometcal.viewEvent") { activity in
    activity.appEntityIdentifier = EntityIdentifier(
        for: EventEntity.self,
        identifier: event.id
    )   // the link that resolves "this"
}
```

Building the same identifier outside SwiftUI (e.g. when constructing an `NSUserActivity` by hand) follows the same shape — set `title`, assign `appEntityIdentifier`, and call `becomeCurrent()` on appearance:

```swift
import AppIntents

@available(iOS 18.2, *)
func makeActivity(for event: EventEntity) -> NSUserActivity {
    let activity = NSUserActivity(activityType: "com.example.cometcal.viewEvent")
    activity.title = event.title
    activity.appEntityIdentifier = EntityIdentifier(for: EventEntity.self, identifier: event.id)
    activity.becomeCurrent()
    return activity
}
```

When you already hold the entity value (not just its id), the single-argument `EntityIdentifier(for:)` builds the same identifier — `EntityIdentifier(for: event)` is equivalent to `EntityIdentifier(for: EventEntity.self, identifier: event.id)`. Reach for the two-argument form when you have only the type and id (as in the list-selection closure below).

**Availability:** `AppEntityAnnotatable` and the `NSUserActivity` conformance are `@available(macOS 15.2, iOS 18.2, watchOS 11.2, tvOS 18.2, visionOS 2.2, *)` — this surface ships from iOS 18.2. `EntityIdentifier(for:)` back-deploys to iOS 16.0; `EntityIdentifier(activityIdentifier:)` is iOS 18.0.

## Annotate list rows with a selection type

When a screen shows a list rather than a single detail view, annotate the rows so Siri can resolve "this" against whichever row is visible or selected. SwiftUI's `.appEntityIdentifier(forSelectionType:_:)` modifier takes the row's selection type (here `EventEntity.ID`, i.e. `UUID`) and a closure that maps each selected value back to an `EntityIdentifier`. CometCal's `CalendarListView` applies it to its event list:

```swift
// CalendarListView body, on the event list
.appEntityIdentifier(forSelectionType: EventEntity.ID.self) { eventID in
    EntityIdentifier(for: EventEntity.self, identifier: eventID)
}
```

This uses the same `EntityIdentifier(for:identifier:)` form as the detail view, driven off the selection value instead of a fixed entity. The SwiftUI `.appEntityIdentifier(forSelectionType:_:)` modifier (and the single-entity `.appEntityIdentifier(_:)` modifier) are **iOS 18.4** (macOS 15.4 / watchOS 11.4 / tvOS 18.4 / visionOS 2.4) — newer than the iOS 18.2 `NSUserActivity` property — so gate a view that uses them at 18.4.

**Which surface to use.** Match the annotation to what's on screen:
- **One primary item** (a detail view, a single full-screen photo): annotate the whole screen — either the foreground `NSUserActivity`'s `appEntityIdentifier` (iOS 18.2) or the single-entity `.appEntityIdentifier(_:)` SwiftUI modifier (iOS 18.4). Siri resolves "this" to that one entity.
- **Several meaningful items at once** (rows in a list, cards in a grid, messages in a thread): annotate each with `.appEntityIdentifier(forSelectionType:_:)` so a request like "the 2nd one" maps to the right row's entity. Don't collapse a multi-item screen to a single activity-level entity.

For either to resolve, the annotated type must be a real `AppEntity` with a working `defaultQuery` (the system looks the entity up by the identifier you supply) — see `entities-and-queries` in the specialist skill.

## Finer-grained onscreen elements

For reporting individual entities visible on screen (rather than a single `NSUserActivity`-level entity), `AppEntityUIElement` / `AppEntityUIElementsContext` provide finer-grained onscreen-element association. Both are iOS 18.4. Consult their current declarations in your SDK before adopting — this reference does not enumerate their members.

**Availability:** `AppEntityUIElement` / `AppEntityUIElementsContext` are `@available(macOS 15.4, iOS 18.4, watchOS 11.4, tvOS 18.4, visionOS 2.4, *)`.
## Availability summary

| API | iOS | macOS | watchOS | tvOS | visionOS |
|---|---|---|---|---|---|
| `AppEntityAnnotatable` / `NSUserActivity.appEntityIdentifier` | 18.2 | 15.2 | 11.2 | 18.2 | 2.2 |
| `EntityIdentifier(for:)` | 16.0 | 13.0 | 9.0 | 16.0 | 1.0* |
| `EntityIdentifier(activityIdentifier:)` | 18.0 | 15.0 | 11.0 | 18.0 | 2.0 |
| `.appEntityIdentifier(_:)` / `.appEntityIdentifier(forSelectionType:_:)` (SwiftUI) | 18.4 | 15.4 | 11.4 | 18.4 | 2.4 |
| `AppEntityUIElement` / `AppEntityUIElementsContext` | 18.4 | 15.4 | 11.4 | 18.4 | 2.4 |
