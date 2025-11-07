//
//  UserSignatureEditorView.swift
//  MNGA
//
//  Created by Codex.
//

import Foundation
import SwiftUI

struct UserSignatureEditTask: TaskProtocol, Hashable {
  typealias Action = String

  static var dummy: Self = .init(action: "")

  let initialSignature: String

  init(action: String, pageToReload _: PageToReload? = nil) {
    initialSignature = action
  }

  var actionTitle: LocalizedStringKey {
    "Edit Signature"
  }

  func buildUploadAttachmentRequest(data _: Data) -> AsyncRequest.OneOf_Value? {
    nil
  }
}

class UserSignaturePostModel: GenericPostModel<UserSignatureEditTask> {
  override func buildContext(with task: UserSignatureEditTask, ignoreError _: Bool = false) {
    let context = Context(task: task, content: task.initialSignature)
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
