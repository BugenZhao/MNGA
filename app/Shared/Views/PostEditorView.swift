//
//  PostEditorView.swift
//  MNGA
//
//  Created by Bugen Zhao on 2021/10/20.
//

import Foundation
import SwiftUI

struct PostReplyTask: TaskProtocol {
  static var dummy: PostReplyTask = .init(action: .init(), pageToReload: nil)

  static func == (lhs: Self, rhs: Self) -> Bool {
    return lhs.action.operation == rhs.action.operation
      && lhs.action.forumID == rhs.action.forumID
      && lhs.action.postID == rhs.action.postID
  }

  func hash(into hasher: inout Hasher) {
    self.action.operation.hash(into: &hasher)
    self.action.forumID.hash(into: &hasher)
    self.action.forumID.hash(into: &hasher)
  }

  var action: PostReplyAction
  let pageToReload: PageToReload?

  var actionTitle: LocalizedStringKey {
    self.action.title
  }

  func buildUploadAttachmentRequest(data: Data) -> AsyncRequest.OneOf_Value? {
    return .uploadAttachment(.with {
      $0.action = self.action
      $0.file = data
    })
  }
}

class PostReplyModel: GenericPostModel<PostReplyTask> {
  override func buildContext(with task: PostReplyTask, ignoreError: Bool = false) {
    logicCallAsync(.postReplyFetchContent(.with {
      $0.action = task.action
    }), errorToastModel: ToastModel.alert) { (response: PostReplyFetchContentResponse) in
      // only build context after successful fetching
      var task = task
      task.action.verbatim = response.verbatim
      let subject = (response.hasSubject || task.action.operation == .new) ? response.subject : nil
      let content = response.content
      let context = Context(task: task, subject: subject, content: content)

      self.onBuildContextSuccess(task: task, context: context)
    } onError: { e in
      if !ignoreError {
        self.onBuildContextError(e)
      }
    }
  }

  override func doSend(with context: GenericPostModel<PostReplyTask>.Context) {
    logicCallAsync(.postReply(.with {
      $0.action = context.task.action
      $0.content = context.content ?? ""
      if let subject = context.subject { $0.subject = subject }
      $0.attachments = context.attachments
    }), errorToastModel: ToastModel.alert)
    { (response: PostReplyResponse) in
      self.onSendSuccess(context: context)
    } onError: { e in
      self.onSendError(e)
    }
  }
}

struct PostEditorView: View {
  var body: some View {
    GenericEditorView<PostReplyTask, PostReplyModel>()
  }
}
