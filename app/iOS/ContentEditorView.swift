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

class ContentEditorModel: ObservableObject {
  enum Panel {
    case sticker
    case none
  }

  private let keyboard = Keyboard.main

  @Published var showing = Panel.none {
    didSet { if showing != .none { keyboard.dismiss() } }
  }
  @Published var selected: NSRange
  @Published var text: String

  @Published var image: Data? = nil
  @Published var showingImagePicker = false

  private let action: PostReplyAction

  @objc func showSticker() {
    self.showing = .sticker
  }

  init(initialText: String, action: PostReplyAction) {
    self._text = .init(initialValue: initialText)
    self._selected = .init(initialValue: NSRange(location: (initialText as NSString).length, length: 0))
    self.action = action
  }

  private func appendTag(_ tag: String) {
    let range = Range(selected, in: text)!
    let selectedText = text[range]
    text.replaceSubrange(range, with: "[\(tag)]\(selectedText)[/\(tag)]")
    let newLocation = selected.location + (tag as NSString).length + 2
    selected = NSRange(location: newLocation, length: selected.length)
  }

  @objc func appendBold() {
    self.appendTag("b")
  }

  @objc func appendDel() {
    self.appendTag("del")
  }

  @objc func showImagePicker() {
    self.showingImagePicker = true
  }

  func insert(_ string: String) {
    let range = Range(selected, in: text)!
    text.replaceSubrange(range, with: string)
    let newLocation = selected.location + (string as NSString).length
    selected = NSRange(location: newLocation, length: 0)
  }
}

struct ContentEditorView: View {
  @Binding var context: PostReplyModel.Context

  @StateObject var model: ContentEditorModel
  @StateObject var keyboard = Keyboard.main

  @EnvironmentObject var presendAttachments: PresendAttachmentsModel

  static func build(context binding: Binding<PostReplyModel.Context>) -> Self {
    let context = binding.wrappedValue
    let model = ContentEditorModel(initialText: context.content ?? "", action: context.task.action)
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
    EmptyView()
  }

  var body: some View {
    VStack {
      List {
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

    logicCallAsync(.uploadAttachment(.with {
      $0.action = context.task.action
      $0.file = data
    }), errorToastModel: ToastModel.alert)
    { (response: UploadAttachmentResponse) in
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

struct PostContentEditorView_Previews: PreviewProvider {
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
