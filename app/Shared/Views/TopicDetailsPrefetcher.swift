//
//  TopicDetailsPrefetcher.swift
//  MNGA
//
//  Background-prefetches topic details for the topics the user is looking at,
//  so opening them is instant via the cache-first path.
//
//  Throttling is intentionally conservative to avoid looking like a crawler and
//  triggering NGA rate limiting:
//   - only fires after scrolling has been idle for a moment (no prefetch while
//     flinging through the list),
//   - only the first N currently-visible topics per batch,
//   - a hard concurrency cap and a randomized delay between requests.
//
//  Foreground requests (tapping into a topic) never go through this gate and
//  use a higher QoS, so prefetch never slows down what the user actually does.
//

import SwiftUI

/// Serializes background prefetch requests: caps concurrency and spaces requests
/// out. Foreground requests do not use this, so they are never throttled.
actor PrefetchGate {
  static let shared = PrefetchGate()

  private var inFlight = 0
  private var waiters = [CheckedContinuation<Void, Never>]()

  /// Wait until a slot is free under the current concurrency cap, honoring the
  /// inter-request delay. `maxConcurrency` and `intervalSeconds` are read live
  /// from preferences so changes take effect without a rebuild.
  func acquire(maxConcurrency: Int, intervalSeconds: Double) async {
    while inFlight >= max(1, maxConcurrency) {
      await withCheckedContinuation { waiters.append($0) }
    }
    inFlight += 1

    // Space requests out with a randomized delay to break machine-like regularity.
    let jitter = Double.random(in: 0.5 ... 1.5)
    let delay = max(0, intervalSeconds) * jitter
    try? await Task.sleep(for: .seconds(delay))
  }

  func release() {
    inFlight = max(0, inFlight - 1)
    if !waiters.isEmpty {
      waiters.removeFirst().resume()
    }
  }
}

private struct TopicDetailsPrefetcherModifier: ViewModifier {
  @Binding var items: [Topic]
  let enabled: Bool

  @StateObject private var prefs = PreferencesStorage.shared

  // Topics already requested this session, so we never prefetch the same one twice.
  @State private var requestedIDs = Set<String>()
  // Topics currently on screen, accumulated via row `onAppear`.
  @State private var visibleIDs = [String]()
  // Debounce task: reset on every visibility change; fires once scrolling stops.
  @State private var idleTask: Task<Void, Never>?

  func body(content: Content) -> some View {
    content
      .environment(\.reportTopicVisible) { id in
        guard enabled else { return }
        if !visibleIDs.contains(id) { visibleIDs.append(id) }
        scheduleAfterIdle()
      }
      .onChange(of: enabled) { _, isOn in if !isOn { cancel() } }
      .onDisappear { cancel() }
  }

  private func cancel() {
    idleTask?.cancel()
    idleTask = nil
  }

  /// Restart the idle timer; only when it elapses (i.e. scrolling has settled)
  /// do we actually kick off prefetching.
  private func scheduleAfterIdle() {
    idleTask?.cancel()
    let idle = max(0.1, prefs.prefetchScrollIdleSeconds)
    idleTask = Task { @MainActor in
      try? await Task.sleep(for: .seconds(idle))
      guard !Task.isCancelled else { return }
      prefetchVisible()
    }
  }

  @MainActor
  private func prefetchVisible() {
    guard enabled else { return }

    // Snapshot visibility order, then keep only fresh, cacheable topics.
    let batchSize = max(1, prefs.prefetchBatchSize)
    let candidates = visibleIDs
      .filter { id in
        guard let topic = items.first(where: { $0.id == id }) else { return false }
        return !topic.hasShortcutForum && !requestedIDs.contains(id)
      }
      .prefix(batchSize)

    let strategy = prefs.topicDetailsWebApiStrategy
    let maxConcurrency = prefs.prefetchMaxConcurrency
    let interval = prefs.prefetchIntervalSeconds

    for id in candidates {
      requestedIDs.insert(id)
      Task.detached(priority: .utility) {
        await PrefetchGate.shared.acquire(maxConcurrency: maxConcurrency, intervalSeconds: interval)
        defer { Task { await PrefetchGate.shared.release() } }

        // Plain first-page load; the Rust service writes the cache on success.
        // The response is discarded — the only goal is warming the cache. Low
        // QoS so foreground taps are never delayed by this. Best-effort: if it
        // fails, opening the topic simply falls back to a normal network load.
        let request = AsyncRequest.OneOf_Value.topicDetails(.with {
          $0.webApiStrategy = strategy
          $0.topicID = id
          $0.localCache = false
          $0.page = 1
        })
        let _: Result<TopicDetailsResponse, LogicError> = await logicCallAsync(
          request,
          requestDispatchQueue: .global(qos: .utility),
          errorToastModel: nil,
        )
      }
    }
  }
}

extension View {
  /// Background-prefetch topic details for the given items when `enabled`.
  func prefetchTopicDetails(for items: Binding<[Topic]>, enabled: Bool) -> some View {
    modifier(TopicDetailsPrefetcherModifier(items: items, enabled: enabled))
  }
}

// MARK: - Visibility reporting

private struct ReportTopicVisibleKey: EnvironmentKey {
  static let defaultValue: (String) -> Void = { _ in }
}

extension EnvironmentValues {
  /// Closure a topic row calls (via `.onAppear`) to report it became visible.
  var reportTopicVisible: (String) -> Void {
    get { self[ReportTopicVisibleKey.self] }
    set { self[ReportTopicVisibleKey.self] = newValue }
  }
}
