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
  enum PageToReload: Equatable, Hashable {
    case last
    case exact(Int)
  }

  struct Task: Equatable, Hashable {
    var action: PostReplyAction
    let pageToReload: PageToReload?
  }

  class Context: Equatable {
    static func == (lhs: PostReplyModel.Context, rhs: PostReplyModel.Context) -> Bool {
      lhs.seed == rhs.seed
    }

    let task: Task
    var subject: String?
    var content: String?
    let seed = UUID()

    init(task: Task, subject: String? = nil, content: String? = nil) {
      self.task = task
      self.subject = subject
      self.content = content
    }

    static var dummy: Context {
      Context.init(task: .init(action: .init(), pageToReload: nil))
    }
  }

  @Published var showEditor = false
  @Published var context: Context? = nil
  @Published var isSending = false

  @Published var sent = nil as Context? {
    didSet { DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.reset() } }
  }

  private var contexts = [Task: Context]()

  private func reset() {
    if let context = self.context {
      self.contexts.removeValue(forKey: context.task)
      self.context = nil
    }
    self.isSending = false
  }

  func show(action: PostReplyAction, pageToReload: PageToReload?) {
    return show(task: .init(action: action, pageToReload: pageToReload))
  }

  private func show(task: Task) {
    if self.showEditor { return }
    self.context = nil
    self.showEditor = true

    if let context = self.contexts[task] {
      self.context = context
    } else {
      self.buildContext(with: task)
    }
  }

  func discardCurrentContext() {
    guard self.showEditor else { return }

    self.showEditor = false
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.reset() }
  }

  private func buildContext(with task: Task, ignoreError: Bool = false) {
    logicCallAsync(.postReplyFetchContent(.with {
      $0.action = task.action
    }), errorToastModel: ToastModel.alert) { (response: PostReplyFetchContentResponse) in
      // only build context after successful fetching
      print(response)
      var task = task
      task.action.modifyAppend = response.modifyAppend
      let subject = (response.hasSubject || task.action.operation == .new) ? response.subject : nil
      let content = response.content
      let context = Context(task: task, subject: subject, content: content)

      self.contexts[task] = context
      withAnimation { self.context = context }
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
      if let subject = context.subject { $0.subject = subject }
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
