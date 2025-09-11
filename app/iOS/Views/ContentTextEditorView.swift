//
//  ContentTextEditorView.swift
//  ContentTextEditorView
//
//  Created by Bugen Zhao on 8/26/21.
//

import Foundation
import SwiftUI

struct ContentTextEditorView: View {
  @ObservedObject var model: ContentEditorModel
  @FocusState private var isTextFieldFocused: Bool

  init(model: ContentEditorModel) {
    self.model = model
  }

  var body: some View {
    TextEditor(text: $model.attributedText, selection: $model.selection)
      .font(.callout)
      .focused($isTextFieldFocused)
      .toolbar {
        ToolbarItemGroup(placement: .keyboard) {
          Button(action: model.showSticker) {
            Image(systemName: "face.smiling")
          }
          Button(action: model.appendBold) {
            Image(systemName: "bold")
          }
          Button(action: model.appendDel) {
            Image(systemName: "strikethrough")
          }
          Button(action: model.showImagePicker) {
            Image(systemName: "photo")
          }
          Spacer()
          Button(action: hideKeyboard) {
            Image(systemName: "keyboard.chevron.compact.down")
          }
        }
      }
  }

  private func hideKeyboard() {
    withAnimation {
      isTextFieldFocused = false
    }
  }
}

// MARK: - Preview

struct ContentTextEditorView_Previews: PreviewProvider {
  static var previews: some View {
    ContentTextEditorView(model: ContentEditorModel(initialText: "Sample text"))
  }
}
