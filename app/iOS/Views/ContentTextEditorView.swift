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

  @ViewBuilder
  var fontSizeMenu: some View {
    let smallSizes = ["10%", "50%", "80%", "90%"]
    let largeSizes = ["110%", "120%", "150%", "200%"]

    Section {
      ForEach(smallSizes, id: \.self) { size in
        Button(action: { model.appendSize(size) }) {
          Label(size, systemImage: "textformat.size.smaller")
        }
      }
    }

    Section {
      ForEach(largeSizes, id: \.self) { size in
        Button(action: { model.appendSize(size) }) {
          Label(size, systemImage: "textformat.size.larger")
        }
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
              HStack(spacing: 20) {
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
                Menu { fontSizeMenu } label: {
                  Image(systemName: "textformat.size")
                }
                Button(action: model.appendCollapsed) {
                  Image(systemName: "chevron.up.chevron.down")
                }
                Button(action: model.appendAt) {
                  Image(systemName: "at")
                }
                Button(action: model.appendQuoted) {
                  Image(systemName: "quote.bubble")
                }
                Button(action: model.appendDice) {
                  Image(systemName: "dice")
                }
                Button(action: model.insertSeparator) {
                  Image(systemName: "minus")
                }
                Button(action: model.appendHeader) {
                  Image(systemName: "h.square")
                }
              }
              .padding(.horizontal)
            }.scrollTargetBehavior(.paging)

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
