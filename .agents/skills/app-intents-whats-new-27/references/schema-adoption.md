# Adopting App Intent Schemas
**SDK Version:** iOS 18.0 and later (the schema-adoption macros)

The schema-adoption macros (`@AppIntent(schema:)`, `@AppEntity(schema:)`, `@AppEnum(schema:)`) are available from iOS 18.0 (macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0). If the user's deployment target is below that, gate the type with `@available(iOS 18.0, *)`. **An individual domain can carry its own, later availability than the macro** — the running example here, the `calendar` domain, is exactly such a case: it is **iOS 27.0** (macOS 27.0, visionOS 27.0; unavailable on watchOS/tvOS), newer than the iOS 18.0 macros, so the calendar types below are gated `@available(iOS 27.0, *)`. Always check a `domain.schema`'s declaration in your SDK and gate to its floor, not the macro's.

A schema mandates a fixed shape for an intent, entity, or enum: a specific set of typed, sometimes-required parameters and a specific result type, so that Apple Intelligence and Siri can invoke your code through a standardized contract. When you adopt a schema, you are promising the system that your type matches that contract. You attach the schema with the macro — `@AppIntent(schema: .<domain>.<action>)` for an intent, `@AppEntity(schema: .<domain>.<type>)` for an entity, `@AppEnum(schema: .<domain>.<type>)` for an enum — and the framework generates the schema conformance (e.g. `AssistantSchemaIntent`) plus the member scaffolding the schema requires. A build tool validates that your type actually satisfies the schema after compilation. Confirm what is available in your SDK before naming one. In the running example, the CometCal calendar sample adopts the public `calendar` domain to let a user create and manage calendar events, and the `system` domain to open one in the app.

## Which domains reach which surface

Pick a domain by the surface you want to light up. The domains below are the **public** schema catalog documented by Apple ([App schema domains](https://developer.apple.com/documentation/appintents/app-schema-domains)); an individual domain can be gated in a given SDK, so confirm a `domain.schema` identifier at its declaration before emitting it. 

| Surface | Domains | What adoption does |
|---|---|---|
| **Apple Intelligence + Siri** (primary) | `audio`, `calendar`, `camera`, `clock`, `files`, `mail`, `maps`, `messages`, `notes`, `phone`, `photos`, `reminders`, `system` (system & in-app search) | Conforming types become discoverable by Apple Intelligence and Siri, and also appear in the Shortcuts app. |
| **Visual Intelligence** (single-purpose) | `visualIntelligence` | Surfaces the app's results when a person points the camera at / selects on-screen content (pairs with `IntentValueQuery` — see `visual-intelligence.md`). |
| **Side-button conversational launch** (single-purpose) | `assistant` | Lets people in Japan launch a voice-based conversational app from the iPhone side button. |
| **Shortcuts app only**  | `books`, `browser`, `journal` (journaling), `presentation`, `reader`, `spreadsheet`, `whiteboard`, `wordProcessor` | Schemas usable in the Shortcuts app; they do **not** make the conforming type discoverable by Apple Intelligence or Siri. |

CometCal's `calendar` domain is an **Apple Intelligence + Siri primary** domain: adopting `.calendar.createEvent`, `.calendar.event`, and friends makes those types discoverable by Apple Intelligence and Siri and surfaces them in the Shortcuts app. An app can adopt schemas from several domains (CometCal uses `calendar` for its create/update/delete actions plus `system` for opening an event). Adopt a domain only when your action genuinely matches its purpose — a forced fit degrades Siri's behavior.

### All-or-nothing domains

Three domains require you to adopt **every** schema in the group if you adopt any of them: **`mail`, `clock`, `messages`**. Xcode flags the missing schemas at build time, so partial adoption won't ship. Don't reach for a single schema from these expecting partial support. 

## The `@Assistant*` → `@App*` rename (the central trap)

The macros are named `@AppIntent(schema:)`, `@AppEntity(schema:)`, and `@AppEnum(schema:)`. The older `@AssistantIntent(schema:)`, `@AssistantEntity(schema:)`, and `@AssistantEnum(schema:)` macros — and the `AssistantSchema` type / `AssistantSchemas.Intent` etc. — are **deprecated and renamed** to the `@App*` forms. Reach for the `@App*` spelling; do not emit `@Assistant*`. CometCal uses only the modern `@App*(schema:)` forms.

The deprecated spelling still compiles, so this is easy to get wrong. If you write it, the compiler emits a deprecation warning that names the replacement, e.g. `'AssistantIntent' is deprecated: renamed to 'AppIntent'`. Migrate by swapping the macro name and leaving the `schema:` argument as-is. (This example uses `.mail.createDraft` rather than a calendar schema: the `calendar` domain is new in iOS 27 and exists only under the modern `@App*` spelling, so it can't illustrate the deprecated form; `mail` is an iOS 18.0 domain present under both spellings.)

```swift
// Deprecated (do not use):
@available(iOS 18.0, *)
@AssistantIntent(schema: .mail.createDraft)
struct ComposeDraft { /* ... */ }

// Current spelling:
@available(iOS 18.0, *)
@AppIntent(schema: .mail.createDraft)
struct ComposeDraft {
    func perform() async throws -> some IntentResult { /* ... */ }
}
```

The schema accessors (`.mail.createDraft`, `.calendar.createEvent`, etc.) are unchanged by the rename — only the macro name and the `AssistantSchema`/`AssistantSchemas.*` type names moved to `AppSchema`/`AppIntentSchema`/`AppEntitySchema`/`AppEnumSchema`.

**Availability:** `@AppIntent(schema:)` / `@AppEntity(schema:)` / `@AppEnum(schema:)` are iOS 18.0+. The `@Assistant*` forms are deprecated.

## Adopting an intent schema

A schema-conforming intent is a normal `AppIntent` — it still has a `perform()` and can be surfaced as an `AppShortcut` — with the extra constraint that its parameters and result must match the schema's contract. Attaching `@AppIntent(schema:)` generates the schema conformance for you; you supply the properties the schema defines. Note that the struct itself declares **no** `: AppIntent` conformance — the macro adds the `AppIntent` conformance and the schema-required shape. Depending on the schema, the macro also confers the capability protocol the schema implies — e.g. `OpenIntent`, `DeleteIntent`, `ShowInAppSearchResultsIntent`, or `AudioPlaybackIntent` — so you implement that protocol's requirements too. Apple Intelligence reads only the properties the schema defines; any extra property you add must be optional and is seen only by the Shortcuts app.

Use a concrete schema only when you can confirm it exists in your SDK. The `calendar` domain is available in (iOS 27.0). For example, `.calendar.createEvent` creates a calendar event and returns it:

```swift
@available(iOS 27.0, *)
@AppIntent(schema: .calendar.createEvent)
struct CreateEventIntent {
    var title: String
    var startDate: Date
    var endDate: Date?
    var location: EventLocation?
    var calendar: CalendarEntity
    var isAllDay: Bool
    var attendees: [AttendeeEntity]

    @Dependency
    var calendarManager: CalendarManager

    func perform() async throws -> some ReturnsValue<EventEntity> {
        // Create the event from the schema-provided values and return the entity.
        let event = try calendarManager.createEvent(/* ... */)
        return .result(value: event.entity)
    }
}
```

The required and optional properties are dictated by the schema, not by you — you can't drop a property the schema requires or change its type. You *may* add optional extras, but they're Shortcuts-only (Siri and Apple Intelligence never fill them — see the traps below). If your functionality doesn't map onto a schema in a domain, write a plain `AppIntent` instead; schema adoption is only for actions that match a published contract. CometCal also adopts `.calendar.updateEvent` and `.calendar.deleteEvent` the same way, and `.system.open` for `OpenEventIntent` (which takes an `EventEntity` and opens it in the app).

If you don't know which domains your SDK exposes, don't guess. Check the current SDK for the domains and schemas available to you rather than naming one that may not be present.

**Availability:** the schema macros are iOS 18.0+, but the `calendar` domain and `.calendar.createEvent` are **iOS 27.0** (macOS 27.0, visionOS 27.0; unavailable on watchOS/tvOS) — a domain can carry a later floor than the macro, so check its declaration in your SDK and gate accordingly.

## Adopting entity and enum schemas

Schemas also standardize the app entities an intent returns or takes as parameters, and the enums used for constrained parameter values. Adopt them the same way, with `@AppEntity(schema:)` and `@AppEnum(schema:)`. The schema decides the required shape, but you may add extra protocol conformances on top of it — CometCal's `EventEntity` also conforms to `IndexedEntity` (for Spotlight) and `OwnershipProvidingEntity`:

```swift
@available(iOS 27.0, *)
@AppEntity(schema: .calendar.event)
struct EventEntity: IndexedEntity, OwnershipProvidingEntity {
    static let defaultQuery = EventEntityQuery()

    var id: UUID
    var calendar: CalendarEntity
    var title: String
    var startDate: Date
    var endDate: Date
    var status: EventEntityStatus?
    // ... the other properties the schema defines ...

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(title)") }

    struct EventEntityQuery: EntityQuery {
        func entities(for identifiers: [UUID]) async throws -> [EventEntity] { [] }
    }
}
```

Entities that never persist can adopt `TransientAppEntity` — CometCal's attendee entity does, since an attendee only exists in the context of an event — and a lookup entity like the calendar itself is a plain `IndexedEntity`:

```swift
@available(iOS 27.0, *)
@AppEntity(schema: .calendar.attendee)
struct AttendeeEntity: TransientAppEntity {
    var person: IntentPerson
    var status: ParticipantStatus?
    // ... the properties the schema defines ...
}

@available(iOS 27.0, *)
@AppEntity(schema: .calendar.calendar)
struct CalendarEntity: IndexedEntity {
    static let defaultQuery = CalendarEntityQuery()
    let id: UUID
    var title: String
    // ...
}
```

An `@AppEnum(schema:)` constrains a parameter to a fixed set of cases. CometCal's event status maps onto `.calendar.eventStatus`:

```swift
@available(iOS 27.0, *)
@AppEnum(schema: .calendar.eventStatus)
enum EventEntityStatus: String {
    case confirmed
    case tentative
    case cancelled

    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .confirmed: "Confirmed",
        .tentative: "Tentative",
        .cancelled: "Cancelled",
    ]
}
```

CometCal adopts several more calendar enums the same way — `.calendar.eventSpan`, `.calendar.attendeeStatus`, and `.calendar.attendeeType`. As with intents, the schema decides the required shape; the macro generates the conformance and validation happens at build time.

**Availability:** the `calendar` entity and enum schemas shown are **iOS 27.0** (macOS 27.0, visionOS 27.0; unavailable on watchOS/tvOS), like the rest of the `calendar` domain.

## How schema conformance is validated

Adopting a schema is a build-time contract, enforced in two places. The macro attaches the schema conformance protocol (e.g. `AssistantSchemaIntent`) and injects the member attributes the schema needs, so a type that isn't shaped like the schema fails to compile. Then, after compilation, the `appintentsmetadataprocessor` build tool extracts your intent's metadata and checks it against the schema definition from the `AppIntentSchemas` package — verifying the required properties are present and correctly typed. A schema-conforming intent flows through the same metadata pipeline as any other `AppIntent`; the schema is what lets Apple Intelligence match a request to your intent through the standardized contract, and it can still be surfaced through `AppShortcut` for Siri and Shortcuts.

## Migrating an existing intent (`isAssistantOnly`)

If an existing intent's properties already match a schema, just add the macro — no other change. If adopting the schema would change the intent's properties in a way that breaks saved shortcuts, don't mutate the old intent: add a **new** schema-conforming intent alongside it and mark the new one Apple-Intelligence-only during the transition.

```swift
@available(iOS 27.0, *)
@AppIntent(schema: .calendar.createEvent)
struct CreateEventIntentAI {
    static let isAssistantOnly: Bool = true   // hidden from Shortcuts; serves Siri / Apple Intelligence only
    var title: String
    var startDate: Date
    func perform() async throws -> some ReturnsValue<EventEntity> { /* ... */ }
}
```

`isAssistantOnly = true` hides the new intent from the Shortcuts app so users don't see a duplicate pair, while the old intent keeps serving existing shortcuts. Remove `isAssistantOnly` once you retire the old intent. Never rename or remove an intent while saved shortcuts or donations depend on it (see the specialist skill's identifiers-are-a-contract guardrail).

## Traps

- **Reaching for the deprecated `@Assistant*` spelling.** Training data over-represents `@AssistantIntent` / `@AssistantEntity` / `@AssistantEnum` and `AssistantSchema`. These are deprecated (renamed to `@AppIntent` / `@AppEntity` / `@AppEnum` and `AppSchema`). Always emit the `@App*` forms.
- **Omitting or mistyping a schema-required property.** The schema fixes the *required* parameter/result shape: omit a required property, or give one the wrong type, and the build fails validation. You *can* add extras beyond the schema — **optional** extra parameters on an intent, or extra properties on an entity — but they surface only in the Shortcuts app; Siri and Apple Intelligence never fill or render them.
- **Assuming a domain exists.** Never emit a domain unless verified in the SDK. When in doubt, use a generic placeholder (`.<domain>.<action>`) and tell the user to check the current SDK for the domains available to them.

## Deployment target below SDK 18

When the user's deployment target is below a schema's floor, gate the type. The schema macros and schema accessors do not exist on older OSes, so an unconditional adoption won't type-check. Gate to the *domain's* floor, which may be newer than the iOS 18.0 macros — the `calendar` domain, for instance, is iOS 27.0:

```swift
@available(iOS 27.0, *)
@AppIntent(schema: .calendar.createEvent)
struct CreateEventIntent {
    var title: String
    var startDate: Date
    func perform() async throws -> some ReturnsValue<EventEntity> { /* ... */ }
}
```

If the same action must also ship on older targets, provide a plain (non-schema) `AppIntent` on the fallback path and register the schema-conforming variant only under the domain's `@available` floor. Don't emit an unconditional `@AppIntent(schema:)`; the typecheck fails with `'AppIntent(schema:)' is only available in iOS 18.0 or newer` (or the schema's own later floor, e.g. `'calendar' is only available in iOS 27.0 or newer`).
