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
  @Published var navigateToTidWithPidAndPage: (tid: String, pid: String, page: Int?)? = nil
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

struct TopicDetailsActionBasicNavigationView: View {
  @ObservedObject var action: TopicDetailsActionModel

  var body: some View {
    let navTopic = Topic.with {
      if let tid = self.action.navigateToTid { $0.id = tid }
    }
    let user = self.action.showUserProfile ?? .init()
    let forum = self.action.navigateToForum ?? .init()
    let view = self.action.navigateToView ?? EmptyView().eraseToAnyView()

    NavigationLink(destination: TopicDetailsView.build(topic: navTopic), isActive: self.$action.navigateToTid.isNotNil()) {}.hidden()
    NavigationLink(destination: UserProfileView.build(user: user), isActive: self.$action.showUserProfile.isNotNil()) {}.hidden()
    NavigationLink(destination: TopicListView.build(forum: forum), isActive: self.$action.navigateToForum.isNotNil()) {}.hidden()
    NavigationLink(destination: view, isActive: self.$action.navigateToView.isNotNil()) {}.hidden()

    let withPidTopic = Topic.with {
      if let tid = self.action.navigateToTidWithPidAndPage?.tid { $0.id = tid }
    }
    let page = self.action.navigateToTidWithPidAndPage?.page
    let postId = PostId.with {
      if let pid = self.action.navigateToTidWithPidAndPage?.pid { $0.pid = pid }
      $0.tid = withPidTopic.id
    }
    NavigationLink(destination: TopicDetailsView.build(topic: withPidTopic, fromPage: page, postIdToJump: postId), isActive: self.$action.navigateToTidWithPidAndPage.isNotNil()) {}.hidden()
  }
}

struct TopicDetailsActionModifier: ViewModifier {
  @StateObject var action = TopicDetailsActionModel()

  func body(content: Content) -> some View {
    content
      .environmentObject(action)
      .background { TopicDetailsActionBasicNavigationView(action: action) }
  }
}

extension View {
  @ViewBuilder
  func withTopicDetailsAction(action: TopicDetailsActionModel? = nil) -> some View {
    if let action = action {
      modifier(TopicDetailsActionModifier(action: action))
    } else {
      modifier(TopicDetailsActionModifier())
    }
  }
}
