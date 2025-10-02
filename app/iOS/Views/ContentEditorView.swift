//
//  ContentEditorView.swift
//  ContentEditorView
//
//  Created by Bugen Zhao on 7/16/21.
//

import AlertToast
import Foundation
import SwiftUI
import SwiftUIX

enum Focus {
  case sendTo
  case subject
  case content
}

struct SubjectTextFieldView: View {
  @Binding var subject: String
  @State var selection: TextSelection?

  let focused: Bool

  func addTagPlaceholder() {
    // FIXME: iOS 26: cannot use unicode (localized) string here, use "..." instead for now.
    let placeholder = "..."
    subject = "[\(placeholder)]\(subject)"
    let range = subject.range(of: placeholder)!
    selection = TextSelection(range: range)
  }

  var body: some View {
    TextField("", text: $subject, selection: $selection)
      .toolbar {
        // Show toolbar only when focused, otherwise it will also be shown in other text fields.
        if focused {
          ToolbarItemGroup(placement: .keyboard) {
            Button(action: addTagPlaceholder) {
              Label("Add Tag", systemImage: "tag")
                .labelStyle(.titleAndIcon)
            }
            Spacer()
          }
        }
      }
  }
}

struct ContentEditorView<T: TaskProtocol, M: GenericPostModel<T>>: View {
  @Binding var context: M.Context

  @StateObject var model: ContentEditorModel
  @StateObject var keyboard = Keyboard.main

  @FocusState var focused: Focus?

  @EnvironmentObject var presendAttachments: PresendAttachmentsModel

  static func build(context binding: Binding<M.Context>) -> Self {
    let context = binding.wrappedValue
    let model = ContentEditorModel(initialText: context.content ?? "")
    return Self(context: binding, model: model)
  }

  @ViewBuilder
  var textEditor: some View {
    ContentTextEditorView(
      model: model,
      focused: Binding(get: { focused == .content }, set: { focused = $0 ? .content : nil })
    )
  }

  @ViewBuilder
  var stickerPanel: some View {
    StickerInputView(model: model)
      .background(.secondarySystemGroupedBackground)
      .frame(maxHeight: 240)
  }

  func setFocusOnAppear() {
    focused = if context.to?.isEmpty == true {
      .sendTo
    } else if context.subject?.isEmpty == true {
      .subject
    } else {
      // Default to focus on content.
      .content
    }
  }

  var body: some View {
    VStack {
      List {
        if context.to != nil {
          Section(header: Text("Send To"), footer: Text("Separate multiple users with space.")) {
            TextField("", text: $context.to ?? "")
              .disableAutocorrection(true)
              .focused($focused, equals: .sendTo)
          }
        }

        if context.subject != nil {
          Section(header: Text("Subject")) {
            SubjectTextFieldView(subject: $context.subject.withDefaultValue(""), focused: focused == .subject)
              .focused($focused, equals: .subject)
          }
        }

        Section(header: Text("Content")) {
          textEditor
            .frame(minHeight: 150)
            .focused($focused, equals: .content)
        }

        if context.anonymous != nil {
          Section {
            Toggle(isOn: $context.anonymous ?? false) {
              Label("Anonymous", systemImage: "theatermasks")
            }.tint(.accentColor)
              .disableWithPlusCheck(.anonymous)
          }
        }
      }

      if !keyboard.isShowing {
        switch model.showing {
        case .sticker: stickerPanel
        case .none: EmptyView()
        }
      }
    }
    .onAppear { setFocusOnAppear() }
    .onReceive(keyboard.$isShown) { shown in if shown { model.showing = .none } }
    .onChange(of: model.text) { context.content = model.text }
    // TODO: use swiftui native photo picker
    .sheet(isPresented: $model.showingImagePicker) { ImagePicker(data: $model.image, encoding: .jpeg(compressionQuality: 0.8)) }
    .onChange(of: model.image) { uploadImageAttachment(data: $1) }
    .toast(isPresenting: $model.image.isNotNil()) { AlertToast(type: .loading) }
  }

  func uploadImageAttachment(data: Data?) {
    guard let data else { return }
    guard let request = context.task.buildUploadAttachmentRequest(data: data) else {
      model.image = nil
      return
    }

    logicCallAsync(request, errorToastModel: ToastModel.editorAlert) { (response: UploadAttachmentResponse) in
      let attachment = response.attachment
      context.attachments.append(attachment)
      presendAttachments.add(url: attachment.url, data: data)

      model.insert("\n[img]./\(attachment.url)[/img]\n")
      model.image = nil
    } onError: { _ in
      model.image = nil
    }
  }
}

struct ContentEditorView_Previews: PreviewProvider {
  struct Preview: View {
    @State var context: PostReplyModel.Context

    static func build(subject: String?) -> Self {
      let context = PostReplyModel.Context.dummy
      context.subject = subject
      return Self(context: context)
    }

    var body: some View {
      ContentEditorView.build(context: $context)
    }
  }

  static var previews: some View {
    Preview.build(subject: "Subject")
    Preview.build(subject: nil)
  }
}
