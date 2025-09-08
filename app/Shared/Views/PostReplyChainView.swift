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
        } else {
          LoadingRowView(high: true)
            .onAppear { loadRemotePost(id: id) }
        }
      }
    }.navigationTitle("Replies")
      .withTopicDetailsAction()
      .environment(\.enableShowReplyChain, false)
      .mayGroupedListStyle()
  }

  func loadRemotePost(id: PostId) {
    logicCallAsync(.topicDetails(.with {
      $0.topicID = id.tid
      $0.postID = id.pid
    })) { (response: TopicDetailsResponse) in
      guard let post = response.replies.first else { return }
      withAnimation { remotePosts[post.id] = post }
    }
  }
}
