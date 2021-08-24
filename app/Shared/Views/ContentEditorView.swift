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
  @Published var moveToPosition = nil as Int? // todo: real two-way binding position
  @Published var position = nil as Int?

  @Binding private var content: String

  init(content: Binding<String>) {
    self._content = content
  }

  @objc func showSticker() {
    self.showing = .sticker
  }

  private func insert(_ string: String, move: Int) {
    if let position = position {
      let index = content.index(content.startIndex, offsetBy: position)
      content.insert(contentsOf: string, at: index)
      moveToPosition = position + move
    } else {
      content.append(contentsOf: string)
    }
  }

  @objc func appendBold() {
    self.insert("[b][/b]", move: 3)
  }
  
  @objc func appendDel() {
    self.insert("[del][/del]", move: 5)
  }
}

struct ContentEditorView: View {
  @Binding var subject: String?
  @Binding var content: String

  @State var introspected = false

  @StateObject var model: ContentEditorModel
  @StateObject var keyboard = Keyboard.main

  static func build(subject: Binding<String?>, content: Binding<String>) -> Self {
    UITextView.appearance().backgroundColor = .clear
    let model = ContentEditorModel(content: content)
    return Self.init(subject: subject, content: content, model: model)
  }

  @ViewBuilder
  var textEditor: some View {
    TextEditor(text: $content).introspectTextView { textView in
      if keyboard.isShowing { // keep tracking the cursor position
        model.position = textView.selectedRange.lowerBound
        if let moveTo = model.moveToPosition {
          model.moveToPosition = nil
          textView.selectedRange = NSRange(location: moveTo, length: 0)
        }
      }

      guard !introspected else { return }
      defer { DispatchQueue.main.async { introspected = true } }

      let inputView = UIInputView.init(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44), inputViewStyle: .keyboard)

      let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
      let flexButton = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
      let doneButton = UIBarButtonItem(image: UIImage(systemName: "keyboard.chevron.compact.down"), style: .done, target: self, action: #selector(textView.doneButtonTapped(button:)))
      let stickerButton = UIBarButtonItem(image: UIImage(systemName: "face.smiling"), style: .plain, target: self.model, action: #selector(ContentEditorModel.showSticker))
      let boldButton = UIBarButtonItem(image: UIImage(systemName: "bold"), style: .plain, target: self.model, action: #selector(ContentEditorModel.appendBold))
      let delButton = UIBarButtonItem(image: UIImage(systemName: "strikethrough"), style: .plain, target: self.model, action: #selector(ContentEditorModel.appendDel))
      toolbar.items = [stickerButton, boldButton, delButton, flexButton, doneButton]

      // make it clear and
      toolbar.isTranslucent = true
      toolbar.setBackgroundImage(UIImage(), forToolbarPosition: .any, barMetrics: .default)
      toolbar.backgroundColor = .clear
      inputView.addSubview(toolbar)

      textView.inputAccessoryView = inputView
      textView.isScrollEnabled = false
      textView.becomeFirstResponder()
    }
  }

  @ViewBuilder
  var stickerPanel: some View {
    StickerInputView(text: $content, position: $model.position)
      .frame(maxHeight: 240)
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
          ZStack { // hack for dynamic height
            textEditor
            Text(content).opacity(0).padding(.all, 8)
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
  }
}

extension UITextView {
  @objc func doneButtonTapped(button: UIBarButtonItem) -> Void {
    self.resignFirstResponder()
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
