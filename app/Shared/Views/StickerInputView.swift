//
//  StickerInputView.swift
//  StickerInputView
//
//  Created by Bugen Zhao on 7/16/21.
//

import Foundation
import SwiftUI

struct StickerInputView: View {
  @Binding var text: String

  var body: some View {
    let rows = [GridItem](repeating: .init(.fixed(50)), count: 4)

    ScrollView(.horizontal) {
      LazyHGrid(rows: rows, spacing: 10) {
        ForEach(stickerImageNames, id: \.self) { name in
          Button(action: { text.append(stickerImageNameToCode(name)) }) {
            Image(name)
              .renderingMode(name.starts(with: "a") ? .template : .original)
              .resizable()
              .aspectRatio(contentMode: .fit)
              .background(name.starts(with: "dt") ? .white : .black.opacity(0.0))
              .frame(height: 50)
          }
        }
      }.padding(.horizontal)
    } .foregroundColor(.primary)
      .frame(height: 240)
  }
}

struct StickerInputView_Previews: PreviewProvider {
  struct Preview: View {
    @State var text = "233"

    var body: some View {
      VStack {
        Text(text)
        StickerInputView(text: $text)
          .background(.secondary.opacity(0.2))
      }
    }
  }

  static var previews: some View {
    Preview()
  }
}
