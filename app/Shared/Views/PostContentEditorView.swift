//
//  PostContentEditorView.swift
//  PostContentEditorView
//
//  Created by Bugen Zhao on 7/16/21.
//

import Foundation
import SwiftUI
import SwiftUIX

struct PostContentPanelView: View {
  @Binding var content: String

  var body: some View {
    StickerInputView(text: $content)
      .frame(maxHeight: 240)
  }
}

struct PostContentEditorView: View {
  @Binding var subject: String?
  @Binding var content: String

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
            TextEditor(text: $content)
              .introspectTextView { textView in
              let toolBar = UIToolbar(frame: CGRect(x: 0, y: 0, width: textView.frame.size.width, height: 44))
              let flexButton = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
              let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(textView.doneButtonTapped(button:)))
              toolBar.items = [flexButton, doneButton]
              toolBar.setItems([flexButton, doneButton], animated: true)
              textView.inputAccessoryView = toolBar
              textView.isScrollEnabled = false
            }
            Text(content).opacity(0).padding(.all, 8)
          } .font(.callout)
            .frame(minHeight: 200)
        }

      } .listStyle(GroupedListStyle())

      PostContentPanelView(content: $content)
        .hiddenIfKeyboardActive()
    }
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
      PostContentEditorView(subject: $subject, content: $content)
    }
  }

  static var previews: some View {
    Preview(subject: "Subject")
    Preview(subject: nil)
  }
}
