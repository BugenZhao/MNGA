//
//  ShortMessageEditorView.swift
//  MNGA
//
//  Created by Bugen Zhao on 2021/10/20.
//

import Foundation
import SwiftUI

struct ShortMessagePostTask: TaskProtocol, Hashable {
  static var dummy = Self(action: .init())

  var action: ShortMessagePostAction

  var actionTitle: LocalizedStringKey {
    action.title
  }

  func buildUploadAttachmentRequest(data _: Data) -> AsyncRequest.OneOf_Value? {
    nil
  }
}

class ShortMessagePostModel: GenericPostModel<ShortMessagePostTask> {
  override func buildContext(with task: ShortMessagePostTask, ignoreError _: Bool = false) {
    let to: String? = switch task.action.operation {
    case .new: ""
    case .newSingleTo: task.action.singleTo
    default: nil
    }

    let context = Context(task: task, to: to, subject: "From MNGA", content: "")
    onBuildContextSuccess(task: task, context: context)
  }

  override func doSend(with context: GenericPostModel<ShortMessagePostTask>.Context) {
    logicCallAsync(.shortMessagePost(.with {
      $0.action = context.task.action
      $0.to = context.to?.split(separator: " ").map(String.init) ?? []
      $0.subject = context.subject ?? "From MNGA"
      $0.content = context.content ?? ""
    }), errorToastModel: ToastModel.editorAlert) { (_: PostReplyResponse) in
      self.onSendSuccess(context: context)
    } onError: { e in
      self.onSendError(e)
    }
  }
}

struct ShortMessageEditorView: View {
  var body: some View {
    GenericEditorView<ShortMessagePostTask, ShortMessagePostModel>()
  }
}
