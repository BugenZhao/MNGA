//
//  PostReplyChainView.swift
//  PostReplyChainView
//
//  Created by Bugen Zhao on 2021/9/11.
//

import Foundation
import SwiftUI

struct PostReplyChainView: View {
  @ObservedObject var baseDataSource: TopicDetailsView.DataSource
  @ObservedObject var votes: VotesModel

  @StateObject var prefs = PreferencesStorage.shared

  @State var remotePosts = [PostId: Post]()
  @State var failed = Set<PostId>()

  let chain: [PostId]

  @ViewBuilder
  func buildRow(post: Post) -> some View {
    PostRowView.build(post: post, vote: votes.binding(for: post))
  }

  var body: some View {
    List {
      ForEach(chain, id: \.hashValue) { id in
        if let post = baseDataSource.items.first(where: { $0.id == id }) {
          buildRow(post: post)
        } else if let post = remotePosts[id] {
          buildRow(post: post)
        } else if failed.contains(id) {
          EmptyRowView(title: "Reply not found. It may have been deleted.")
        } else {
          LoadingRowView(high: true)
            .onAppear { loadRemotePost(id: id) }
        }
      }
    }.navigationTitle("Replies")
      .withTopicDetailsAction()
      .environment(\.enableShowReplyChain, false)
      .mayGroupedListStyle()
      .refreshable { failed.removeAll() }
  }

  func loadRemotePost(id: PostId) {
    logicCallAsync(.topicDetails(.with {
      $0.webApiStrategy = prefs.topicDetailsWebApiStrategy
      $0.topicID = id.tid
      $0.postID = id.pid
    })) { (response: TopicDetailsResponse) in
      withAnimation {
        if let post = response.replies.first {
          remotePosts[id] = post
        } else {
          failed.insert(id)
        }
      }
    }
  }
}
