//
//  ContentEditorView.swift
//  MNGA (macOS)
//
//  Created by Bugen Zhao on 2021/10/5.
//

import AlertToast
import Foundation
import SwiftUI
import SwiftUIX

class ContentEditorModel: ObservableObject {
  @Published var selected: NSRange
  @Published var text: String

  private let action: PostReplyAction

  init(initialText: String, action: PostReplyAction) {
    _text = .init(initialValue: initialText)
    _selected = .init(initialValue: NSRange(location: (initialText as NSString).length, length: 0))
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
    return Self(context: binding, model: model)
  }

  var body: some View {
    VStack(alignment: .leading) {
      if context.subject != nil {
        Text("Subject").font(.headline)
        TextField("", text: $context.subject ?? "")
      }

      Text("Content").font(.headline)
      TextEditor(text: $context.content ?? "")
        .scrollDisabled(true)
        .font(.callout)
        .frame(minHeight: 250)

//      Spacer()
//      StickerInputView(text: $model.text, selected: $model.selected)
//        .background(.secondarySystemGroupedBackground)
//        .frame(maxHeight: 240)
    }
    .onChange(of: model.text) { text in context.content = text }
  }
}
