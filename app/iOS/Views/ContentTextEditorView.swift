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

  @Binding var focused: Bool

  @ViewBuilder
  var colorMenu: some View {
    ForEach(ContentCombiner.palette.elements, id: \.key) { element in
      let name = element.key
      let color = element.value

      Button(action: { model.appendColor(name) }) {
        Label(name, systemImage: "circle.fill")
          .tint(color)
      }
    }
  }

  var body: some View {
    TextEditor(text: $model.text, selection: $model.selection)
      .toolbar {
        // Show toolbar only when focused, otherwise it will also be shown in other text fields.
        if focused {
          ToolbarItemGroup(placement: .keyboard) {
            ScrollView(.horizontal, showsIndicators: false) {
              HStack(spacing: 22) {
                Button(action: model.showSticker) {
                  Image(systemName: "face.smiling")
                }
                Button(action: model.showImagePicker) {
                  Image(systemName: "photo")
                }
                Button(action: model.appendBold) {
                  Image(systemName: "bold")
                }
                Button(action: model.appendDel) {
                  Image(systemName: "strikethrough")
                }
                Menu { colorMenu } label: {
                  Image(systemName: "paintpalette")
                }
                Button(action: model.appendCollapsed) {
                  Image(systemName: "chevron.up.chevron.down")
                }
                Button(action: model.insertSeparator) {
                  Image(systemName: "minus")
                }
                Button(action: model.appendHeader) {
                  Image(systemName: "h.square")
                }
              }
              .padding(.horizontal)
            }

            Spacer()

            Button(action: hideKeyboard) {
              Image(systemName: "keyboard.chevron.compact.down")
            }
          }
        }
      }
  }

  private func hideKeyboard() {
    withAnimation {
      focused = false
    }
  }
}

// MARK: - Preview

struct ContentTextEditorView_Previews: PreviewProvider {
  static var previews: some View {
    ContentTextEditorView(model: ContentEditorModel(initialText: "Sample text"), focused: .constant(true))
  }
}
