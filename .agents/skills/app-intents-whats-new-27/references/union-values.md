# Union Values as Shortcuts Parameters
**SDK Version:** iOS 27.0 and later

If the user's deployment target is below iOS 27 / macOS 27 / watchOS 27 / tvOS 27 / visionOS 27, the parameter behavior in this reference requires availability gating. The `@UnionValue` macro itself is older and back-deploys (`@available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)`), but the `AppUnionValue` / `AppUnionValueCasesProviding` conformances that let a union type act as a Shortcuts parameter — and the parameter-summary interpolation for its components — are `@available(anyAppleOS 27.0, *)`. In practice a `@UnionValue` type is only usable as a `@Parameter` once the deployment target is 27.0, so gate at **27.0** wherever the parameter behavior is what you need. See "Deployment target below SDK 27" below for the gating shape.

`@UnionValue` lets one value be any of several unrelated types — `case place(PlaceDescriptor)` or `case address(String)`. The sibling `visual-intelligence.md` covers `@UnionValue` for multi-type visual-query **results** (returning `[LandmarkResult]` from an `IntentValueQuery`). This reference is about the other direction: using a `@UnionValue` type as **parameter input** in a Shortcuts action, where the new-in-27 `AppUnionValue` / `AppUnionValueCasesProviding` conformances give the union the nominal identity and per-case metadata the editor needs to render a case picker and a parameter summary.

The running example is drawn from Apple's published **CometCal** calendar sample, whose `EventLocation` union lets a calendar event's location be either a structured place or a free-text address.

## What `@UnionValue` produces

Applying `@UnionValue` to an `enum` whose cases each wrap a single type generates an extension conforming the enum to `AppUnionValue` (plus the supporting App Intents value conformance the macro adds). That conformance is what carries the union into App Intents: `AppUnionValue` refines `TypeDisplayRepresentable` and declares an associated `Cases` type (`associatedtype Cases: AppUnionValueCasesProviding where Cases.UnionValue == Self`). The macro also synthesizes the nested `Cases` enum — one bare case per union case — and conforms it to `AppUnionValueCasesProviding`, which itself refines `AppEnum`. That `AppEnum`-backed `Cases` enum is the nominal, metadata-bearing type Shortcuts uses to offer the user a "which kind?" picker before it collects the associated value.

Without `AppUnionValue`/`AppUnionValueCasesProviding` (iOS 27.0) the macro would still expand, but the union would lack the case metadata and nominal identity required to surface it as a selectable parameter — these two conformances are the new-in-27 piece that makes a union a first-class Shortcuts input.

**Availability:** `AppUnionValue` and `AppUnionValueCasesProviding` are both `@available(anyAppleOS 27.0, *)`. The `@UnionValue` macro is `@available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)`.

## A `@UnionValue` enum as a `@Parameter`

Declare the union with `@UnionValue`, then use it directly as the `Value` type of a `@Parameter`. Each case's wrapped type (`PlaceDescriptor`, `String`, …) must itself be a valid App Intents value — an `AppEntity`, `AppEnum`, or a built-in like `String`. Because the parameter behavior depends on the 27.0 conformances, gate the union type and the intent at iOS 27.0.

```swift
import AppIntents
import GeoToolbox

@available(iOS 27.0, *)
@UnionValue
enum EventLocation {
    case place(PlaceDescriptor)    // PlaceDescriptor from GeoToolbox
    case address(String)
}

@available(iOS 27.0, *)
@AppIntent(schema: .calendar.createEvent)
struct CreateEventIntent {

    // Shortcuts renders a case picker (Place vs. Address) then collects the value.
    var location: EventLocation?

    @MainActor
    func perform() async throws -> some ReturnsValue<EventEntity> {
        // switch over the selected case
        if case .address(let str) = location {
            // use the free-text address
        } else if case .place(let place) = location {
            // use the structured PlaceDescriptor
        }
        // ...
    }
}
```

CometCal reaches `EventLocation` through the `.calendar.createEvent` schema, so the union arrives as a schema-provided property rather than an explicit `@Parameter`. Most apps adopt `@UnionValue` on their **own** intents, where you declare the same union type directly as a `@Parameter` — this is the shape you'll write most often:

```swift
@available(iOS 27.0, *)
struct SetEventLocationIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Event Location"

    // Shortcuts renders a case picker (Place vs. Address), then collects the value.
    @Parameter(title: "Location")
    var location: EventLocation

    func perform() async throws -> some IntentResult {
        switch location {
        case .place(let place):    _ = place    // structured PlaceDescriptor
        case .address(let text):   _ = text     // free-text address
        }
        return .result()
    }
}
```

**Availability:** the union type is usable as a `@Parameter` only from iOS 27.0 (the `AppUnionValue` conformance floor). Gate the `@UnionValue` type and the enclosing intent with `@available(iOS 27.0, *)`.

## Custom case metadata and type display

Let the macro synthesize the `Cases` enum; do not hand-roll it. Provide user-facing strings by implementing the `AppUnionValue` requirements in an extension: `typeDisplayRepresentation` names the union in the editor, and `caseDisplayRepresentations` maps each `Cases` value to the label shown in the picker. Both have empty default implementations, so an un-customized union shows blank strings — supply real ones for anything user-visible. (CometCal's `EventLocation` leaves these at their defaults; the extension below shows the shape you'd add.)

```swift
@available(iOS 27.0, *)
extension EventLocation {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Event Location" }

    static let caseDisplayRepresentations: [Cases: DisplayRepresentation] = [
        .place: "Place",
        .address: "Address",
    ]
}
```

`AppUnionValueCasesProviding` inherits both `typeDisplayRepresentation` and `caseDisplayRepresentations` from the associated `UnionValue`, so you write the metadata once on the union and the generated `Cases` enum picks it up automatically.

**Availability:** `AppUnionValue.typeDisplayRepresentation` / `caseDisplayRepresentations` and the `AppUnionValueCasesProviding` inheriting defaults are `@available(anyAppleOS 27.0, *)`.

## Union components in parameter summaries

A union parameter exposes two components for `Summary` interpolation: `\.$parameter.type` (the case name of the selected value) and `\.$parameter.value` (the associated value of that case). These are surfaced by `IntentParameter.AppUnionValueComponent` (`.type` / `.value`) and are available only when `Value.ValueType: AppUnionValue`. 

```swift
@available(iOS 27.0, *)
@AppIntent(schema: .calendar.createEvent)
struct CreateEventIntent {
    static var parameterSummary: some ParameterSummary {
        Summary("Create event at \(\.$location.type): \(\.$location.value)")
    }
    // ...
}
```

**Availability:** the `ParameterSummaryString.StringInterpolation` overload for union components and `IntentParameter.AppUnionValueComponent` are `@available(anyAppleOS 27.0, *)`.

## Don't hand-roll the Cases enum

Never define the `Cases` enum or its conformance yourself — the macro generates it and wires `Cases.UnionValue == Self`; a hand-written one will not satisfy the `where` clauses. Put customization in an extension on the union, not on `Cases`.

Also mind the availability split: the `@UnionValue` macro attribute reads as iOS 18.0, but that floor is a red herring for parameter use. The parameter picker, custom metadata, and summary interpolation all depend on the 27.0 conformances, so gate at iOS 27.0 whenever the union is a Shortcuts parameter — matching the RESULTS guidance in `visual-intelligence.md`.

## Deployment target below SDK 27

When the user's deployment target is below SDK 27 and the answer needs a `@UnionValue` type as a parameter, gate the union and its intent behind an availability check and provide a fallback path for older OS versions:

```swift
@available(iOS 27.0, *)
@UnionValue
enum EventLocation {
    case place(PlaceDescriptor)
    case address(String)
}

@available(iOS 27.0, *)
@AppIntent(schema: .calendar.createEvent)
struct CreateEventIntent {
    var location: EventLocation?
    // ...
}
```

Gate to the conformance floor — iOS 27.0 / macOS 27.0 / watchOS 27.0 / tvOS 27.0 / visionOS 27.0 — even though the `@UnionValue` macro attribute itself back-deploys to iOS 18.0; the parameter behavior is what pins it to 27.0. For deployment targets below 27, provide separate scalar parameters (e.g. one for the structured place, one for the address string) or split into two intents rather than a union. Don't emit an unconditional `@UnionValue` parameter; the typecheck will fail with `'AppUnionValue' is only available in iOS 27.0 or newer`.

## Availability summary

| Symbol | Availability | Notes |
|---|---|---|
| `@UnionValue` (macro) | iOS 18.0, macOS 15.0, watchOS 11.0, tvOS 18.0, visionOS 2.0 | Older floor; expands to the `AppUnionValue` conformance (plus the macro's supporting value conformance) |
| `AppUnionValue` | anyAppleOS 27.0 | Public protocol; refines `TypeDisplayRepresentable`; nominal identity + `Cases` |
| `AppUnionValueCasesProviding` | anyAppleOS 27.0 | Public protocol; refines `AppEnum`; the generated `Cases` enum conforms |
| `AppUnionValue.typeDisplayRepresentation` / `caseDisplayRepresentations` | anyAppleOS 27.0 | Empty defaults; override in an extension on the union |
| `IntentParameter.AppUnionValueComponent` (`.type` / `.value`) | anyAppleOS 27.0 | Union components for parameter summaries |
| `ParameterSummaryString.StringInterpolation` union overload | anyAppleOS 27.0 | Enables `\.$param.type` / `\.$param.value` in `Summary` |
| Effective gate for a `@UnionValue` **parameter** | iOS 27.0 | Parameter/picker/summary behavior requires the 27.0 conformances |
