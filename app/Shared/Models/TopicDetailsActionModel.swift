//
//  TopicDetailsActionModel.swift
//  TopicDetailsActionModel
//
//  Created by Bugen Zhao on 2021/9/11.
//

import Foundation
import Combine
import SwiftUI

class TopicDetailsActionModel: ObservableObject {
  @Published var scrollToPid: String? = nil
  @Published var showingReplyChain: [PostId]? = nil
  @Published var navigateToTid: String? = nil
  @Published var showUserProfile: User? = nil
  @Published var navigateToAuthorOnly: String? = nil
  @Published var navigateToLocalMode: Bool = false

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
    self.showingReplyChain = replyChain(from: from)
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
