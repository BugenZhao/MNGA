//
//  ContentEditorView.swift
//  MNGA (macOS)
//
//  Created by Bugen Zhao on 2021/10/5.
//

import Foundation
import SwiftUI
import SwiftUIX
import AlertToast

class ContentEditorModel: ObservableObject {
  @Published var selected: NSRange
  @Published var text: String

  private let action: PostReplyAction

  init(initialText: String, action: PostReplyAction) {
    self._text = .init(initialValue: initialText)
    self._selected = .init(initialValue: NSRange(location: (initialText as NSString).length, length: 0))
    self.action = action
  }
}


struct ContentEditorView: View {
  @Binding var context: PostReplyModel.Context

  @StateObject var model: ContentEditorModel

  @EnvironmentObject var presendAttachments: PresendAttachmentsModel

  static func build(context binding: Binding<PostReplyModel.Context>) -> Self {
    let context = binding.wrappedValue
    let model = ContentEditorModel(initialText: context.content ?? "", action: context.task.action)
    return Self.init(context: binding, model: model)
  }

  var body: some View {
    Text("Stub")
  }
}
