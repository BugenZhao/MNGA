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
  }
}

struct PostContentEditorView: View {
  @Binding var content: String
  @ObservedObject var keyboard = Keyboard.main

  var body: some View {
    TextEditor(text: $content)
      .introspectTextView { textView in
      let toolBar = UIToolbar(frame: CGRect(x: 0, y: 0, width: textView.frame.size.width, height: 44))
      let flexButton = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
      let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(textView.doneButtonTapped(button:)))
      toolBar.items = [flexButton, doneButton]
      toolBar.setItems([flexButton, doneButton], animated: true)
      textView.inputAccessoryView = toolBar
    }
    if keyboard.isShowing {

    } else {
      Divider()
      PostContentPanelView(content: $content)
    }
  }
}

extension UITextView {
  @objc func doneButtonTapped(button: UIBarButtonItem) -> Void {
    self.resignFirstResponder()
  }
}
