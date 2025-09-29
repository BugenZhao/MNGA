//
//  GenericPostModel.swift
//  MNGA
//
//  Created by Bugen Zhao on 2021/10/20.
//

import Combine
import Foundation
import SwiftUI

enum PageToReload: Equatable, Hashable {
  case last
  case exact(Int)

  static var first: Self {
    .exact(1)
  }
}

protocol TaskProtocol: Hashable {
  associatedtype Action

  static var dummy: Self { get }

  init(action: Action, pageToReload: PageToReload?)

  var actionTitle: LocalizedStringKey { get }

  func buildUploadAttachmentRequest(data: Data) -> AsyncRequest.OneOf_Value?
}

class GenericPostModel<Task: TaskProtocol>: ObservableObject {
  class Context: Equatable {
    static func == (lhs: Context, rhs: Context) -> Bool {
      lhs.seed == rhs.seed
    }

    let task: Task

    var to: String?
    var subject: String?
    var content: String?
    var attachments: [PostAttachment]
    var anonymous: Bool?

    let seed = UUID()

    init(task: Task, to: String? = nil, subject: String? = nil, content: String? = nil, anonymous: Bool? = nil) {
      self.to = to
      self.task = task
      self.subject = subject
      self.content = content
      attachments = []
      self.anonymous = anonymous
    }

    static var dummy: Context {
      Context(task: .dummy)
    }
  }

  // MARK: States

  @Published var showEditor = false {
    willSet {
      if showEditor == true, newValue == false, context != nil, sent == nil {
        ToastModel.showAuto(.success("Draft Saved"))
      }
    }
  }

  @Published var context: Context? = nil
  @Published var isSending = false
  @Published var sent = nil as Context? {
    didSet { DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.reset() } }
  }

  private var contexts = [Task: Context]()
  private func reset() {
    if let context {
      contexts.removeValue(forKey: context.task)
      self.context = nil
    }
    isSending = false
  }

  // MARK: Interface

  func showAfter(action: Task.Action) {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
      self.show(action: action)
    }
  }

  func show(action: Task.Action, pageToReload: PageToReload? = nil) {
    guard checkPlus(.postOrReply) else { return }
    let task = Task(action: action, pageToReload: pageToReload)

    if showEditor { return }
    context = nil
    showEditor = true

    if let context = contexts[task] {
      self.context = context
    } else {
      buildContext(with: task)
    }
  }

  func discardCurrentContext() {
    guard showEditor else { return }

    reset()
    showEditor = false
  }

  func send() {
    guard let context else { return }
    isSending = true
    doSend(with: context)
  }

  // MARK: Build Context

  func buildContext(with _: Task, ignoreError _: Bool = false) {
    preconditionFailure()
  }

  func onBuildContextError(_: Error) {
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { self.showEditor = false }
  }

  func onBuildContextSuccess(task: Task, context: Context) {
    contexts[task] = context
    withAnimation { self.context = context }
  }

  // MARK: Send Request

  func doSend(with _: Context) {
    preconditionFailure()
  }

  func onSendError(_: Error) {
    isSending = false
  }

  func onSendSuccess(context: Context) {
    sent = context
    showEditor = false
    #if os(iOS)
      HapticUtils.play(type: .success)
    #endif
  }
}
