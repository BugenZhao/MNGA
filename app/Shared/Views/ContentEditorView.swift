//
//  ContentEditorView.swift
//  ContentEditorView
//
//  Created by Bugen Zhao on 7/16/21.
//

import Foundation
import SwiftUI
import SwiftUIX

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

  @objc func showSticker() {
    self.showing = .sticker
  }

  init(initialText: String) {
    self._text = .init(initialValue: initialText)
    self._selected = .init(initialValue: NSRange(location: (initialText as NSString).length, length: 0))
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
}

struct ContentEditorView: View {
  @Binding var subject: String?
  @Binding var contentToCommit: String

  @StateObject var model: ContentEditorModel
  @StateObject var keyboard = Keyboard.main

  static func build(subject: Binding<String?>, content: Binding<String>) -> Self {
    let model = ContentEditorModel(initialText: content.wrappedValue)
    return Self.init(subject: subject, contentToCommit: content, model: model)
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
        if subject != nil {
          Section(header: Text("Subject")) {
            TextField("", text: $subject ?? "")
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
      .onChange(of: model.text) { text in contentToCommit = text }
  }
}

struct PostContentEditorView_Previews: PreviewProvider {
  struct Preview: View {
    @State var subject: String?
    @State var content = ""

    var body: some View {
      ContentEditorView.build(subject: $subject, content: $content)
    }
  }

  static var previews: some View {
    Preview(subject: "Subject")
    Preview(subject: nil)
  }
}
