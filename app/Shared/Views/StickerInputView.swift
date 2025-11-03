//
//  StickerInputView.swift
//  StickerInputView
//
//  Created by Bugen Zhao on 7/16/21.
//

import Foundation
import SwiftUI

struct StickerInputView: View {
  @ObservedObject var model: ContentEditorModel

  var body: some View {
    let rows = [GridItem](repeating: .init(.fixed(50)), count: 4)

    ScrollView(.horizontal) {
      LazyHGrid(rows: rows, spacing: 10) {
        ForEach(stickerImageNames, id: \.self) { name in
          Button(action: { insert(name: name) }) {
            Image(name)
              .renderingMode(name.starts(with: "a") ? .template : .original)
              .resizable()
              .scaledToFit()
              .background(name.starts(with: "dt") ? .white : .black.opacity(0.0))
              .frame(height: 50)
          }
        }
      }.padding(.horizontal)
    }.foregroundColor(.primary)
      .frame(height: 240)
  }

  func insert(name: String) {
    let code = stickerImageNameToCode(name)
    model.insert(code)
  }
}

struct StickerInputView_Previews: PreviewProvider {
  struct Preview: View {
    @StateObject var model = ContentEditorModel(initialText: "233")

    var body: some View {
      VStack {
        Text(model.text)
        StickerInputView(model: model)
          .background(.secondary.opacity(0.2))
      }
    }
  }

  static var previews: some View {
    Preview()
  }
}
