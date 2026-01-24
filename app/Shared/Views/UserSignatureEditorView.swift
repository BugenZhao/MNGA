//
//  UserSignatureEditorView.swift
//  MNGA
//
//  Created by Codex.
//

import Foundation
import SwiftUI

struct UserSignatureEditAction: Hashable {
  var userID = ""
  var initialSignature = ""
}

struct UserSignatureEditTask: TaskProtocol, Hashable {
  typealias Action = UserSignatureEditAction

  static var dummy = Self(action: .init())

  var action: UserSignatureEditAction

  var actionTitle: LocalizedStringKey {
    "Edit Signature"
  }

  func buildUploadAttachmentRequest(data _: Data) -> AsyncRequest.OneOf_Value? {
    nil
  }
}

class UserSignaturePostModel: GenericPostModel<UserSignatureEditTask> {
  override func buildContext(with task: UserSignatureEditTask, ignoreError _: Bool = false) {
    let context = Context(task: task, content: task.action.initialSignature)
    onBuildContextSuccess(task: task, context: context)
  }

  override func doSend(with context: GenericPostModel<UserSignatureEditTask>.Context) {
    let signature = context.content ?? ""

    logicCallAsync(.userSignatureUpdate(.with {
      $0.signature = signature
    }), errorToastModel: ToastModel.editorAlert) { (_: UserSignatureUpdateResponse) in
      self.onSendSuccess(context: context)
    } onError: { error in
      self.onSendError(error)
    }
  }
}

struct UserSignatureEditorView: View {
  var body: some View {
    GenericEditorView<UserSignatureEditTask, UserSignaturePostModel>()
  }
}
