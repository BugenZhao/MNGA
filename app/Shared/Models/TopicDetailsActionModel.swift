//
//  TopicDetailsActionModel.swift
//  TopicDetailsActionModel
//
//  Created by Bugen Zhao on 2021/9/11.
//

import Foundation
import Combine

class TopicDetailsActionModel: ObservableObject {
  @Published var scrollToPid: String? = nil
  @Published var showingReplyChain: [PostId]? = nil
  @Published var navigateToTid: String? = nil
  @Published var showUserProfile: User? = nil
  
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
