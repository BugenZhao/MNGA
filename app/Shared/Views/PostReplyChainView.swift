//
//  PostReplyChainView.swift
//  PostReplyChainView
//
//  Created by Bugen Zhao on 2021/9/11.
//

import Foundation
import SwiftUI

struct PostReplyChainView: View {
  @ObservedObject var votes: VotesModel

  @ObservedObject var resolver: QuotedPostResolver
  @StateObject private var action = TopicDetailsActionModel()
  @StateObject var prefs = PreferencesStorage.shared
  @Environment(\.dismiss) private var dismiss

  let chain: [PostId]
  let topic: Topic
  let locateFloorInTopic: ((Post) -> Void)?

  @ViewBuilder
  func buildRow(post: Post) -> some View {
    PostRowView.build(
      post: post,
      screenshotTopic: topic,
      vote: votes.binding(for: post),
      locateFloor: locateFloorInTopic == nil ? nil : { _ in
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
          locateFloorInTopic?(post)
        }
      },
    )
  }

  var body: some View {
    List {
      ForEach(chain, id: \.hashValue) { id in
        if let post = resolver.post(for: id) {
          buildRow(post: post)
        } else if resolver.failed.contains(id) {
          EmptyRowView(title: "Reply not found. It may have been deleted.")
        } else {
          LoadingRowView(high: true)
            .onAppear { resolver.load(id: id) }
        }
      }
    }
    .environmentObject(resolver)
    .navigationTitle("Replies")
    .withTopicDetailsAction(action: action)
    .environment(\.enableShowReplyChain, false)
    .mayGroupedListStyle()
    .refreshable { resolver.resetFailures() }
    .navigationDestination(item: $action.navigateToAuthorOnly) { author in
      TopicDetailsView.build(topic: topic, only: author)
    }
  }
}
