//
//  ContentTextEditorView.swift
//  ContentTextEditorView
//
//  Created by Bugen Zhao on 8/26/21.
//

import Foundation
import SwiftUI

struct ContentTextEditorView: UIViewRepresentable {
  @ObservedObject var model: ContentEditorModel

  init(model: ContentEditorModel) {
    self.model = model
  }

  func makeUIView(context: Context) -> UITextView {
    let textView = UITextView()
    textView.delegate = context.coordinator

    let inputView = UIInputView.init(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44), inputViewStyle: .keyboard)

    let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
    let flexButton = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
    let doneButton = UIBarButtonItem(image: UIImage(systemName: "keyboard.chevron.compact.down"), style: .done, target: self, action: #selector(textView.doneButtonTapped(button:)))
    let stickerButton = UIBarButtonItem(image: UIImage(systemName: "face.smiling"), style: .plain, target: self.model, action: #selector(ContentEditorModel.showSticker))
    let imageButton = UIBarButtonItem(image: UIImage(systemName: "photo"), style: .plain, target: self.model, action: #selector(ContentEditorModel.showImagePicker))
    let boldButton = UIBarButtonItem(image: UIImage(systemName: "bold"), style: .plain, target: self.model, action: #selector(ContentEditorModel.appendBold))
    let delButton = UIBarButtonItem(image: UIImage(systemName: "strikethrough"), style: .plain, target: self.model, action: #selector(ContentEditorModel.appendDel))
    let sepButton = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
    sepButton.width = 12

    toolbar.items = [stickerButton, imageButton, sepButton, boldButton, delButton, flexButton, doneButton]

    // make the toolbar translucent with keyboard
    toolbar.isTranslucent = true
    toolbar.setBackgroundImage(UIImage(), forToolbarPosition: .any, barMetrics: .default)
    toolbar.backgroundColor = .clear
    inputView.addSubview(toolbar)

    textView.inputAccessoryView = inputView
    textView.becomeFirstResponder()
    textView.isSelectable = true
    textView.isUserInteractionEnabled = true
    textView.font = UIFont.preferredFont(forTextStyle: .callout)
    textView.backgroundColor = .clear

    return textView
  }

  func updateUIView(_ textView: UITextView, context: Context) {
    let text = model.text
    let selected = model.selected

    if text != textView.text {
      textView.text = text
    }
    textView.selectedRange = selected
  }

  func makeCoordinator() -> Coordinator {
    return Coordinator(model: model)
  }

  class Coordinator: NSObject, UITextViewDelegate {
    let model: ContentEditorModel

    init(model: ContentEditorModel) {
      self.model = model
    }

    func textViewDidChange(_ textView: UITextView) {
      model.text = textView.text
    }

    func textViewDidChangeSelection(_ textView: UITextView) {
      model.selected = textView.selectedRange
    }
  }
}

extension UITextView {
  @objc func doneButtonTapped(button: UIBarButtonItem) -> Void {
    self.resignFirstResponder()
  }
}
