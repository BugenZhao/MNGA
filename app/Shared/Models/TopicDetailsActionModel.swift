//
//  TopicDetailsActionModel.swift
//  TopicDetailsActionModel
//
//  Created by Bugen Zhao on 2021/9/11.
//

import Combine
import Foundation
import SwiftUI

class TopicDetailsActionModel: ObservableObject {
  @Published var scrollToPid: String? = nil
  @Published var scrollToFloor: Int? = nil
  @Published var showingReplyChain: [PostId]? = nil
  @Published var navigateToTid: String? = nil
  @Published var navigateToForum: Forum? = nil
  @Published var showUserProfile: User? = nil
  @Published var navigateToAuthorOnly: String? = nil
  @Published var navigateToLocalMode: Bool = false
  @Published var navigateToView: AnyView? = nil

  private var replyTo = [PostId: PostId]()

  func recordReply(from: PostId, to: PostId) {
    replyTo[from] = to
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
}

struct EnableAuthorOnlyKey: EnvironmentKey {
  static let defaultValue: Bool = true
}

extension EnvironmentValues {
  var enableAuthorOnly: Bool {
    get { self[EnableAuthorOnlyKey.self] }
    set { self[EnableAuthorOnlyKey.self] = newValue }
  }
}

struct EnableShowReplyChainKey: EnvironmentKey {
  static let defaultValue: Bool = true
}

extension EnvironmentValues {
  var enableShowReplyChain: Bool {
    get { self[EnableShowReplyChainKey.self] }
    set { self[EnableShowReplyChainKey.self] = newValue }
  }
}

struct CurrentlyLocalModeKey: EnvironmentKey {
  static let defaultValue: Bool = false
}

extension EnvironmentValues {
  var currentlyLocalMode: Bool {
    get { self[CurrentlyLocalModeKey.self] }
    set { self[CurrentlyLocalModeKey.self] = newValue }
  }
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
      .navigationDestination(item: $action.showUserProfile) { UserProfileView.build(user: $0) }
      .navigationDestination(item: $action.navigateToForum) { TopicListView.build(forum: $0) }
      .navigationDestination(isPresented: $action.navigateToView.isNotNil()) { action.navigateToView } // TODO(ng): use item
  }
}

extension View {
  // With this modifier, the navigation in post content can correctly work.
  @ViewBuilder
  func withTopicDetailsAction(action: TopicDetailsActionModel? = nil) -> some View {
    if let action {
      modifier(TopicDetailsActionModifier(action: action))
    } else {
      modifier(TopicDetailsActionModifier())
    }
  }
}
