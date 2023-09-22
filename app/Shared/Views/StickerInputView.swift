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
  @Binding var selected: NSRange

  var body: some View {
    let rows = [GridItem](repeating: .init(.fixed(50)), count: 4)

    ScrollView(.horizontal) {
      LazyHGrid(rows: rows, spacing: 10) {
        ForEach(stickerImageNames, id: \.self) { name in
          Button(action: { insert(name: name) }) {
            Image(name)
              .renderingMode(name.starts(with: "a") ? .template : .original)
              .resizable()
              .aspectRatio(contentMode: .fit)
              .background(name.starts(with: "dt") ? .white : .black.opacity(0.0))
              .frame(height: 50)
          }
        }
      }.padding(.horizontal)
    }.foregroundColor(.primary)
      .frame(height: 240)
  }

  func insert(name: String) {
    let range = Range(selected, in: text)!
    let code = stickerImageNameToCode(name)
    text.replaceSubrange(range, with: code)
    let newLocation = selected.location + (code as NSString).length
    selected = NSRange(location: newLocation, length: 0)
  }
}

struct StickerInputView_Previews: PreviewProvider {
  struct Preview: View {
    @State var text = "233"
    @State var selected = NSRange()

    var body: some View {
      VStack {
        Text(text)
        StickerInputView(text: $text, selected: $selected)
          .background(.secondary.opacity(0.2))
      }
    }
  }

  static var previews: some View {
    Preview()
  }
}
