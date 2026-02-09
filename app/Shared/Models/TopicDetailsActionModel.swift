//
//  TopicDetailsActionModel.swift
//  TopicDetailsActionModel
//
//  Created by Bugen Zhao on 2021/9/11.
//

import Combine
import Foundation
import SwiftUI

enum AuthorOnly: Hashable {
  case uid(String)
  case anonymous(PostId?)
}

class TopicDetailsActionModel: ObservableObject {
  @Published var scrollToPid: String? = nil
  @Published var scrollToFloor: Int? = nil
  @Published var showingReplyChain: [PostId]? = nil
  @Published var showingQuotedReplies: [PostId]? = nil
  @Published var navigateToTid: String? = nil
  @Published var navigateToPid: String? = nil
  @Published var navigateToForum: Forum? = nil
  @Published var showUserProfile: User? = nil
  @Published var navigateToRemoteUserID: String? = nil
  @Published var navigateToRemoteUserName: String? = nil
  @Published var navigateToAuthorOnly: AuthorOnly? = nil
  @Published var navigateToLocalMode: Bool = false
  @Published var navigateToView: AnyView? = nil
  @Published private var quotedTargets = Set<PostId>()

  private var replyTo = [PostId: PostId]()
  private var quotedBy = [PostId: Set<PostId>]()
  private var indexedReplyTo = [PostId: PostId]()
  private var indexingReplyRelations = false

  func recordReply(from: PostId, to: PostId) {
    replyTo[from] = to

    guard indexingReplyRelations else { return }

    if let oldTarget = indexedReplyTo[from], oldTarget != to {
      quotedBy[oldTarget]?.remove(from)
      if quotedBy[oldTarget]?.isEmpty == true {
        quotedBy.removeValue(forKey: oldTarget)
      }
    }
    indexedReplyTo[from] = to
    quotedBy[to, default: []].insert(from)
  }

  private func removeIndexedReply(from: PostId) {
    if let to = indexedReplyTo.removeValue(forKey: from) {
      quotedBy[to]?.remove(from)
      if quotedBy[to]?.isEmpty == true {
        quotedBy.removeValue(forKey: to)
      }
    }
    replyTo.removeValue(forKey: from)
  }

  func indexReplyRelations(in posts: some Sequence<Post>) {
    for post in posts {
      removeIndexedReply(from: post.id)
      // Reuse the exact parsing path used by post rendering so the indexed
      // relation is consistent with existing reply-chain behavior.
      indexingReplyRelations = true
      let combiner = ContentCombiner(
        actionModel: self,
        id: post.id,
        postDate: post.postDate,
        defaultFont: .body,
        defaultColor: .primary,
      )
      combiner.visit(spans: post.content.spans)
      indexingReplyRelations = false
    }
    quotedTargets = Set(quotedBy.keys)
  }

  func replyChain(from: PostId) -> [PostId] {
    var from = from
    var chain = [from]
    while let to = replyTo[from] {
      chain.append(to)
      from = to
    }
    return chain.reversed()
  }

  func showReplyChain(from: PostId) {
    showingReplyChain = replyChain(from: from)
  }

  func quotedReplies(for postId: PostId) -> [PostId] {
    let ids = quotedBy[postId] ?? []
    return ids.sorted { lhs, rhs in
      if lhs.tid != rhs.tid {
        return lhs.tid < rhs.tid
      }
      let l = Int(lhs.pid)
      let r = Int(rhs.pid)
      if let l, let r {
        return l < r
      }
      return lhs.pid < rhs.pid
    }
  }

  func hasQuotedReplies(for postId: PostId) -> Bool {
    quotedTargets.contains(postId)
  }

  func showQuotedReplies(for postId: PostId) {
    let replies = quotedReplies(for: postId)
    guard !replies.isEmpty else { return }
    showingQuotedReplies = [postId] + replies.filter { $0 != postId }
  }
}

extension EnvironmentValues {
  @Entry var enableAuthorOnly: Bool = true
}

extension EnvironmentValues {
  @Entry var enableShowReplyChain: Bool = true
}

extension EnvironmentValues {
  @Entry var currentlyLocalMode: Bool = false
}

// MARK: TopicDetailsAction

struct TopicDetailsActionModifier: ViewModifier {
  @StateObject var action = TopicDetailsActionModel()

  func body(content: Content) -> some View {
    content
      .environmentObject(action)
      .navigationDestination(item: $action.navigateToTid) { tid in
        let navTopic = Topic.with { $0.id = tid }
        TopicDetailsView.build(topic: navTopic)
      }
      .navigationDestination(item: $action.navigateToPid) { pid in
        let postId = PostId.with { $0.pid = pid }
        TopicDetailsView.build(onlyPost: (id: postId, atPage: nil))
      }
      .navigationDestination(item: $action.showUserProfile) { UserProfileView.build(user: $0) }
      .navigationDestination(item: $action.navigateToForum) { TopicListView.build(forum: $0) }
      .navigationDestination(item: $action.navigateToRemoteUserID) { RemoteUserProfileView(id: $0) }
      .navigationDestination(item: $action.navigateToRemoteUserName) { RemoteUserProfileView(name: $0) }
      .navigationDestination(isPresented: $action.navigateToView.isNotNil()) { action.navigateToView } // TODO(ng): use item
  }
}

extension View {
  // With this modifier, the navigation in post content can correctly work.
  // NOTE: Callers must wire navigationDestination for:
  // - navigateToAuthorOnly
  // - navigateToLocalMode
  // - showingReplyChain
  // - showingQuotedReplies
  @ViewBuilder
  func withTopicDetailsAction(action: TopicDetailsActionModel? = nil) -> some View {
    if let action {
      modifier(TopicDetailsActionModifier(action: action))
    } else {
      modifier(TopicDetailsActionModifier())
    }
  }
}
