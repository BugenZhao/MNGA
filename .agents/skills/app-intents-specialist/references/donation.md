# Donating Intents for Proactive Suggestions

App Intents power Siri Suggestions, Spotlight prediction, and the proactive "next action" surfaces — but only for actions the system *knows happened*. The non-obvious part, especially coming from SiriKit's automatic `INInteraction` donations: **App Intents does not auto-donate actions a person takes inside your own app's UI.** The system donates only the intents *it* runs — when someone runs your intent from the Shortcuts app or via Siri. A tap in your app that performs the same logical action produces no donation unless you make one. Without donations, prediction has nothing to learn from, and your suggestions stay empty.

## Donate after in-app actions — the system won't do it for you

After a person completes an action in your app's own interface (a tap or gesture in your **UI**, not an intent the system ran), build the matching `AppIntent` and hand it to `IntentDonationManager.shared`. Donate *after* the action succeeds (not before), and put enough detail in the intent to replay the action later; when the intent declares a return value, donate its **result** too (via `donate(intent:result:)`) so prediction learns the outcome, not just the invocation. Don't donate from inside an intent's `perform()`; the system already donates the intents it runs, so a donation there would double-count.

```swift
// AVOID: assuming in-app actions are auto-donated. This action is invisible to
// prediction — Siri Suggestions and Spotlight never learn the user plays this
// playlist every morning, because nothing was ever donated.
func userTappedPlay(_ playlist: PlaylistEntity) async {
    await player.play(playlist)
    // …no donation → no prediction signal
}
```

```swift
// PREFER: donate the matching intent after the action completes.
func userTappedPlay(_ playlist: PlaylistEntity) async {
    await player.play(playlist)
    try? await IntentDonationManager.shared.donate(
        intent: PlayPlaylistIntent(playlist: playlist)
    )
}
```

When the intent declares a return value, hand the system the result alongside the intent:

```swift
// Include the result when the intent returns one, so prediction learns the outcome.
try? await IntentDonationManager.shared.donate(
    intent: PlayPlaylistIntent(playlist: playlist),
    result: .result(value: playlist)
)
```

## Pick the throwing or non-throwing overload deliberately

`donate(intent:)` comes in two shapes: an `async throws` variant that reports whether the donation succeeded, and a synchronous variant that fails quietly. Use the async/throwing form when you need to know a donation landed (tests, production diagnostics); the synchronous form is fire-and-forget. When user data behind a donation is deleted, delete the stale donation too, so prediction quality doesn't degrade.

## `PredictableIntent` is not the donation hook

It is easy to assume `PredictableIntent` is how you feed prediction. It is not — `PredictableIntent` only supplies the *display descriptions* the system shows when it presents a suggestion (via `predictionConfiguration`). It does not donate anything. You still call `IntentDonationManager.shared.donate(...)` for the signal; `PredictableIntent` just makes the resulting suggestion read well.

Donation is the evergreen "teach the system what already happened" signal. On iOS 27+ there is a separate, complementary surface for pushing the entities that matter *right now* into suggestion surfaces (`RelevantEntities`) — for that, see the **relevance-and-context** reference in the sibling `app-intents-whats-new-27` skill.
