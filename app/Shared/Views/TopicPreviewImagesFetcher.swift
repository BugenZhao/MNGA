//
//  TopicPreviewImagesFetcher.swift
//  MNGA
//
//  Fetches preview images lazily for a list of topics and writes the result
//  back into the bound items. Shared by the forum topic list, search results
//  and hot topics so each can opt in via its own preference toggle.
//

import SwiftUI

private struct TopicPreviewImagesFetcherModifier: ViewModifier {
  @Binding var items: [Topic]
  let enabled: Bool

  // Results fetched this session, keyed by topic ID. An empty array means the
  // topic is confirmed to have no preview images. List refreshes replace
  // `items` with server-fresh topics that carry no preview URLs; this
  // dictionary lets us restore them without another network round-trip.
  @State private var fetchedUrls = [String: [String]]()
  // Topics with a request currently in flight, so scrolling or list changes
  // don't double-request them. Failed requests are removed to allow a retry.
  @State private var inFlightIDs = Set<String>()

  func body(content: Content) -> some View {
    content
      .onChange(of: items.map(\.id)) { _, _ in fetchIfNeeded() }
      // A refresh replaces the items with fresh copies whose preview URLs are
      // empty (the list API doesn't carry them) while the IDs stay the same:
      // watch the URLs too, so the wipe itself triggers a backfill.
      .onChange(of: items.map(\.previewImageUrls)) { _, _ in fetchIfNeeded() }
      .onChange(of: enabled) { _, isEnabled in if isEnabled { fetchIfNeeded() } }
      .onAppear { fetchIfNeeded() }
  }

  private func fetchIfNeeded() {
    guard enabled else { return }

    backfillKnownUrls()

    for topic in items {
      guard topic.previewImageUrls.isEmpty,
            !topic.hasShortcutForum,
            !topic.id.isMNGAMockID,
            fetchedUrls[topic.id] == nil,
            !inFlightIDs.contains(topic.id)
      else { continue }

      inFlightIDs.insert(topic.id)
      logicCallAsync(.topicPreviewImages(.with {
        $0.topicID = topic.id
      }), errorToastModel: nil) { (response: TopicPreviewImagesResponse) in
        inFlightIDs.remove(response.topicID)
        fetchedUrls[response.topicID] = response.imageUrls
        guard !response.imageUrls.isEmpty else { return }
        if let index = items.firstIndex(where: { $0.id == response.topicID }) {
          withAnimation {
            items[index].previewImageUrls = response.imageUrls
          }
        }
      } onError: { _ in
        // Allow a later retry for this topic if the request failed.
        inFlightIDs.remove(topic.id)
      }
    }
  }

  /// Restore already-fetched URLs into items that lost them (e.g. after a
  /// refresh), in a single write so the list publishes only one update.
  private func backfillKnownUrls() {
    var updated = items
    var didBackfill = false
    for (index, topic) in updated.enumerated() {
      guard topic.previewImageUrls.isEmpty,
            let known = fetchedUrls[topic.id],
            !known.isEmpty
      else { continue }
      updated[index].previewImageUrls = known
      didBackfill = true
    }
    if didBackfill {
      items = updated
    }
  }
}

extension View {
  /// Lazily fetch preview images for the given topics when `enabled`.
  func fetchTopicPreviewImages(for items: Binding<[Topic]>, enabled: Bool) -> some View {
    modifier(TopicPreviewImagesFetcherModifier(items: items, enabled: enabled))
  }
}
