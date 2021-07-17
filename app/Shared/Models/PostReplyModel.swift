//
//  PostReplyModel.swift
//  PostReplyModel
//
//  Created by Bugen Zhao on 7/16/21.
//

import Foundation
import Combine
import SwiftUI

class PostReplyModel: ObservableObject {
  struct Task: Equatable, Hashable {
    let action: PostReplyAction
    let pageToReload: Int?
  }

  class Context: Equatable {
    static func == (lhs: PostReplyModel.Context, rhs: PostReplyModel.Context) -> Bool {
      lhs.seed == rhs.seed
    }

    let task: Task
    var content: String?
    let seed = UUID()

    init(task: Task, content: String? = nil) {
      self.task = task
      self.content = content
    }
  }

  @Published var showEditor = false
  @Published var context: Context? = nil
  @Published var isSending = false

  @Published var sent = nil as Context? {
    didSet { DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.reset() } }
  }

  private var contexts = [Task: Context]()

  var contentBinding: Binding<String> {
    Binding<String>.init(get: { self.context?.content ?? "" }, set: { self.context?.content = $0 })
  }

  private func reset() {
    if let context = self.context {
      self.contexts.removeValue(forKey: context.task)
      self.context = nil
    }
    self.isSending = false
  }
  
  func show(action: PostReplyAction, pageToReload: Int? = nil) {
    return show(task: .init(action: action, pageToReload: pageToReload))
  }

  func show(task: Task) {
    if self.showEditor { return }
    self.showEditor = true

    if let context = self.contexts[task] {
      self.context = context
    } else {
      self.buildContext(with: task)
    }
  }

  func forceRefreshCurrentContext() {
    guard self.showEditor else { return }
    guard let task = self.context?.task else { return }

    buildContext(with: task)
  }

  private func buildContext(with task: Task, ignoreError: Bool = false) {
    logicCallAsync(.postReplyFetchContent(.with {
      $0.action = task.action
    }), errorToastModel: ToastModel.alert) { (response: PostReplyFetchContentResponse) in
      // only build context after successful fetching
      let context = Context.init(task: task, content: response.content)
      self.contexts[task] = context
      self.context = context
    } onError: { e in
      if !ignoreError {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.showEditor = false }
      }
    }
  }

  func send() {
    guard let context = self.context else { return }

    self.isSending = true

    logicCallAsync(.postReply(.with {
      $0.action = context.task.action
      $0.content = context.content ?? ""
    }), errorToastModel: ToastModel.alert)
    { (response: PostReplyResponse) in
      self.showEditor = false
      self.sent = context
      #if os(iOS)
        HapticUtils.play(type: .success)
      #endif
    } onError: { e in
      self.isSending = false
    }
  }
}
