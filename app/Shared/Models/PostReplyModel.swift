//
//  PostReplyModel.swift
//  PostReplyModel
//
//  Created by Bugen Zhao on 7/16/21.
//

import Foundation
import Combine

class PostReplyModel: ObservableObject {
  @Published var showEditor = false {
    didSet {
      if showEditor == false {
        self.reset()
      }
    }
  }
  @Published var content: String? = nil
  @Published var action: PostReplyAction? = nil
  @Published var isSending = false
  @Published var sent = 0

  private func reset() {
    self.action = nil
    self.content = nil
    self.isSending = false
  }

  func show(action: PostReplyAction) {
    if self.showEditor { return }

    self.action = action
    self.showEditor = true

    logicCallAsync(.postReplyFetchContent(.with {
      $0.action = action
    }), errorToastModel: ToastModel.alert) { (response: PostReplyFetchContentResponse) in
      self.content = response.content
    } onError: { e in
      self.content = ""
    }
  }

  func send() {
    guard let action = self.action else { return }

    self.isSending = true

    logicCallAsync(.postReply(.with {
      $0.action = action
      $0.content = self.content ?? ""
    }), errorToastModel: ToastModel.alert)
    { (response: PostReplyResponse) in
      self.showEditor = false
      self.sent += 1
      #if os(iOS)
        HapticUtils.play(type: .success)
      #endif
    } onError: { e in
      self.isSending = false
    }
  }
}
