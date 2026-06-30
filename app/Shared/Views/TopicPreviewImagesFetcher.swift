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

  // Topics we've already requested this session, so a topic (even one with no
  // images) is not requested again while scrolling or refreshing.
  @State private var requestedIDs = Set<String>()

  func body(content: Content) -> some View {
    content
      .onChange(of: items.map(\.id)) { _, _ in fetchIfNeeded() }
      .onChange(of: enabled) { _, isEnabled in if isEnabled { fetchIfNeeded() } }
      .onAppear { fetchIfNeeded() }
  }

  private func fetchIfNeeded() {
    guard enabled else { return }

    for topic in items {
      guard topic.previewImageUrls.isEmpty,
            !topic.hasShortcutForum,
            !requestedIDs.contains(topic.id)
      else { continue }

      requestedIDs.insert(topic.id)
      logicCallAsync(.topicPreviewImages(.with {
        $0.topicID = topic.id
      }), errorToastModel: nil) { (response: TopicPreviewImagesResponse) in
        guard !response.imageUrls.isEmpty else { return }
        if let index = items.firstIndex(where: { $0.id == response.topicID }) {
          withAnimation {
            items[index].previewImageUrls = response.imageUrls
          }
        }
      } onError: { _ in
        // Allow a later retry for this topic if the request failed.
        requestedIDs.remove(topic.id)
      }
    }
  }
}

extension View {
  /// Lazily fetch preview images for the given topics when `enabled`.
  func fetchTopicPreviewImages(for items: Binding<[Topic]>, enabled: Bool) -> some View {
    modifier(TopicPreviewImagesFetcherModifier(items: items, enabled: enabled))
  }
}
