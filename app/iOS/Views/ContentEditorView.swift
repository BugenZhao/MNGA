//
//  ContentEditorView.swift
//  ContentEditorView
//
//  Created by Bugen Zhao on 7/16/21.
//

import Foundation
import SwiftUI
import SwiftUIX
import AlertToast

struct ContentEditorView<T: TaskProtocol, M: GenericPostModel<T>>: View {
  @Binding var context: M.Context

  @StateObject var model: ContentEditorModel
  @StateObject var keyboard = Keyboard.main

  @EnvironmentObject var presendAttachments: PresendAttachmentsModel

  static func build(context binding: Binding<M.Context>) -> Self {
    let context = binding.wrappedValue
    let model = ContentEditorModel(initialText: context.content ?? "")
    return Self.init(context: binding, model: model)
  }

  @ViewBuilder
  var textEditor: some View {
    ContentTextEditorView(model: self.model)
  }

  @ViewBuilder
  var stickerPanel: some View {
    StickerInputView(text: $model.text, selected: $model.selected)
      .background(.secondarySystemGroupedBackground)
      .frame(maxHeight: 240)
  }

  var body: some View {
    VStack {
      List {
        if context.to != nil {
          Section(header: Text("Send To"), footer: Text("Separate multiple users with space.")) {
            TextField("", text: $context.to ?? "")
              .disableAutocorrection(true)
          }
        }
        
        if context.subject != nil {
          Section(header: Text("Subject")) {
            TextField("", text: $context.subject ?? "")
          }
        }

        Section(header: Text("Content")) {
          ZStack(alignment: .topLeading) { // hack for dynamic height
            textEditor
            Text(model.text).opacity(0).padding(.all, 6)
          } .font(.callout)
            .frame(minHeight: 250)
        }
      } .listStyle(GroupedListStyle())

      if !keyboard.isShowing {
        switch model.showing {
        case .sticker: stickerPanel
        case .none: EmptyView()
        }
      }
    }
      .onReceive(keyboard.$isShown) { shown in if shown { model.showing = .none } }
      .onChange(of: model.text) { text in context.content = text }
      .sheet(isPresented: $model.showingImagePicker) { ImagePicker(data: $model.image, encoding: .jpeg(compressionQuality: 0.8)) }
      .onChange(of: model.image) { image in uploadImageAttachment(data: image) }
      .toast(isPresenting: $model.image.isNotNil()) { AlertToast(type: .loading) }
  }

  func uploadImageAttachment(data: Data?) {
    guard let data = data else { return }
    guard let request = context.task.buildUploadAttachmentRequest(data: data) else {
      model.image = nil
      return
    }

    logicCallAsync(request, errorToastModel: ToastModel.alert) { (response: UploadAttachmentResponse) in
      let attachment = response.attachment
      context.attachments.append(attachment)
      presendAttachments.add(url: attachment.url, data: data)

      model.insert("\n[img]./\(attachment.url)[/img]")
      model.image = nil
    } onError: { e in
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
      return Self.init(context: context)
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
