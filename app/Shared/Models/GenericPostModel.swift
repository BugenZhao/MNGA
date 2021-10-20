//
//  GenericPostModel.swift
//  MNGA
//
//  Created by Bugen Zhao on 2021/10/20.
//

import Foundation
import Combine
import SwiftUI

enum PageToReload: Equatable, Hashable {
  case last
  case exact(Int)
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
    var subject: String?
    var content: String?
    var attachments: [PostAttachment]

    let seed = UUID()

    init(task: Task, subject: String? = nil, content: String? = nil) {
      self.task = task
      self.subject = subject
      self.content = content
      self.attachments = []
    }

    static var dummy: Context {
      Context.init(task: .dummy)
    }
  }


  // MARK: States

  @Published var showEditor = false {
    willSet {
      if showEditor == true, newValue == false, self.context != nil, self.sent == nil {
        ToastModel.hud.message = .success("Draft Saved")
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
    if let context = self.context {
      self.contexts.removeValue(forKey: context.task)
      self.context = nil
    }
    self.isSending = false
  }


  // MARK: Interface

  public func show(action: Task.Action, pageToReload: PageToReload?) {
    let task = Task(action: action, pageToReload: pageToReload)

    if self.showEditor { return }
    self.context = nil
    self.showEditor = true

    if let context = self.contexts[task] {
      self.context = context
    } else {
      self.buildContext(with: task)
    }
  }

  public func discardCurrentContext() {
    guard self.showEditor else { return }

    self.reset()
    self.showEditor = false
  }

  public func send() {
    guard let context = self.context else { return }
    self.isSending = true
    self.doSend(with: context)
  }

  // MARK: Build Context

  func buildContext(with task: Task, ignoreError: Bool = false) {
    preconditionFailure()
  }

  func onBuildContextError(_ e: Error) {
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.showEditor = false }
  }

  func onBuildContextSuccess(task: Task, context: Context) {
    self.contexts[task] = context
    withAnimation { self.context = context }
  }


  // MARK: Send Request

  func doSend(with context: Context) {
    preconditionFailure()
  }

  func onSendError(_ e: Error) {
    self.isSending = false
  }

  func onSendSuccess(context: Context) {
    self.sent = context
    self.showEditor = false
    #if os(iOS)
      HapticUtils.play(type: .success)
    #endif
  }
}
