//
//  PostReplyModel.swift
//  PostReplyModel
//
//  Created by Bugen Zhao on 7/16/21.
//

import Foundation
import Combine

class PostReplyModel: ObservableObject {
  @Published var showEditor = false
  @Published var content = ""
  @Published var action: PostReplyAction? = nil
  @Published var isSending = false

  func show(action: PostReplyAction, content: String) {
    self.action = action
    self.content = content
    self.showEditor = true
  }

  func send() {
    guard let action = self.action else { return }


    self.isSending = true
    logicCallAsync(.postReply(.with {
        $0.action = action
        $0.content = self.content
      }), errorToastModel: ToastModel.alert)
    { (response: PostReplyResponse) in
      self.action = nil
      self.content = ""
      self.showEditor = false
      self.isSending = false

      #if os(iOS)
        HapticUtils.play(type: .success)
      #endif
    } onError: { e in
      self.isSending = false
    }
  }
}
