# Proactively Surfacing Relevant Entities
**SDK Version:** iOS 27.0 and later

If the user's deployment target is below iOS 27 / macOS 27 / watchOS 27 / tvOS 27 / visionOS 27, the new APIs in this reference (`RelevantEntities` and its `.shared` singleton, `updateEntities(_:for:)`, `removeEntities(_:)`, `removeAllEntities()`, `removeEntities(_:from:)`, `removeAllEntities(for:)`, `AppEntityContext`, and the `AudioContext` factories `.nowPlaying` / `.workout` / `.workout(activityType:)` / `.workout(intensityLevel:)`) require availability gating. `RelevantIntent` and `RelevantIntentManager` are older (iOS 17.0) and do not need iOS 27 gating.

`RelevantEntities` is a **narrow, media-focused** API: your app **donates the playable media items it owns — songs, albums, artists, playlists, radio stations, podcasts, and the like — so the system can suggest something to *play* (including items the person hasn't searched for or played before) in an audio scenario such as a workout or Now Playing.** It is **not** a general-purpose relevance or discovery mechanism, and it does **not** surface arbitrary entities: the only shipping contexts are audio (`AudioContext`), and your donations are candidates for the system's *media-playback* suggestions. (Making content *searchable* is Spotlight indexing; teaching the system *patterns from actions people took* is interaction donation via `IntentDonationManager` — different surfaces for different purposes. Don't reach for `RelevantEntities` for either.) You donate the full current set with `updateEntities(_:for:)` — each call replaces the previous set for that context — and retract it when it no longer applies; if the person doesn't open your app, the system expires the donations after roughly four weeks. The shipping contexts are **Now Playing** (`.audio(.nowPlaying)`) and **workout** (`.audio(.workout)` and its activity-type / intensity variants) — for example, surfacing a running playlist the moment someone starts a run. The running example is **TravelTracking**, whose travel-podcast feature donates the `EpisodeEntity` a person is currently listening to.

## Relevant entities

`RelevantEntities` is a `Sendable` struct reached through its `static let shared` singleton. `updateEntities(_:for:)` registers an array of `any AppEntity` as relevant for a given `AppEntityContext`; the call *replaces* the entities previously registered for that context, so pass the full current set each time rather than appending. Register when the context genuinely applies — when the person is listening to something, or has started a workout — so the set reflects what's relevant now.

```swift
import AppIntents

@available(iOS 27.0, *)
func updateNowPlaying(_ episode: EpisodeEntity) async throws {
    // Replaces whatever was previously published for the now-playing context.
    try await RelevantEntities.shared.updateEntities([episode], for: .audio(.nowPlaying))
}
```

**Availability:** iOS 27, macOS 27, watchOS 27, tvOS 27, visionOS 27 (`anyAppleOS 27.0`).

## Removing relevant entities

`RelevantEntities` offers four retraction calls so nothing lingers in system surfaces once it is no longer relevant. `removeEntities(_:from:)` retracts specific entities from one context; `removeAllEntities(for:)` clears an entire context; `removeEntities(_:)` and `removeAllEntities()` operate across every context your app published. Pair every publish with a matching removal.

```swift
import AppIntents

@available(iOS 27.0, *)
func retireNowPlaying(_ episode: EpisodeEntity) async throws {
    // Retract a specific entity from one context...
    try await RelevantEntities.shared.removeEntities([episode], from: .audio(.nowPlaying))
    // ...clear the whole context...
    try await RelevantEntities.shared.removeAllEntities(for: .audio(.nowPlaying))
    // ...or clear everything TravelTracking published, across all contexts.
    try await RelevantEntities.shared.removeAllEntities()
}
```

**Availability:** iOS 27, macOS 27, watchOS 27, tvOS 27, visionOS 27 (`anyAppleOS 27.0`).

## App entity context

`AppEntityContext` names the situation an entity is relevant to. It is a `Hashable`, `Sendable` value type, so you can store it, compare it, and key collections on it. It's produced by `AppEntityContext.audio(_:)`, which takes an `AudioContext`; the shipping `AudioContext` values are `.nowPlaying` (the system's Now Playing control or complication) and — from the HealthKit overlay — `.workout` (a workout of any type), `.workout(activityType:)` for a specific `HKWorkoutActivityType`, and `.workout(intensityLevel:)` for a `.low` / `.medium` / `.high` intensity. A more specific workout context is a stronger hint than the broad one, and you can register entities for several contexts at once.

```swift
import AppIntents

@available(iOS 27.0, *)
func nowPlayingContext() -> AppEntityContext {
    .audio(.nowPlaying)                    // the system's Now Playing control / complication
}

// Workout contexts need the HealthKit overlay.
import HealthKit

@available(iOS 27.0, *)
func runningContext() -> AppEntityContext {
    .audio(.workout(activityType: .running))   // e.g. surface a running playlist when a run starts
}
```

**Availability:** iOS 27, macOS 27, watchOS 27, tvOS 27, visionOS 27 (`anyAppleOS 27.0`). `.nowPlaying` is in AppIntents; the `.workout` factories and `WorkoutIntensityLevel` come from the HealthKit overlay (`import HealthKit`), same availability.

## Relevant intents (widget configuration)

`RelevantIntent` is the adjacent, older surface for marking a *widget-configuration* intent as relevant — it dates to iOS 17.0, so don't describe it as new in iOS 27 or conflate it with the iOS 27 `RelevantEntities` entity API (the two are easy to mix up by name). Its initializer `init(_:widgetKind:relevance:)` takes a `WidgetConfigurationIntent`, a `widgetKind` string, and a `relevance` of type `RelevantContext`, which originates in the **RelevanceKit** framework but is re-exported by AppIntents, so `import AppIntents` resolves it — an explicit `import RelevanceKit` is optional. You submit the results through `RelevantIntentManager.shared.updateRelevantIntents(_:)`. Use it only for widget-configuration intents, not for arbitrary intents.

```swift
import AppIntents
import RelevanceKit                  // optional — RelevantContext is re-exported by AppIntents

@available(iOS 17.0, *)
@available(tvOS, unavailable)
func publishRelevantWidgets(_ intents: [TravelGalleryWidgetIntent],
                            relevance: RelevantContext) async throws {
    let relevant = intents.map {
        RelevantIntent($0, widgetKind: "TravelGallery", relevance: relevance)
    }
    try await RelevantIntentManager.shared.updateRelevantIntents(relevant)
}
```

**Availability:** `RelevantIntent` / `RelevantIntentManager`: iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0. The `init(_:widgetKind:relevance:)` initializer is iOS 17.0 / macOS 14.0 / watchOS 10.0 and is **unavailable on tvOS**.
