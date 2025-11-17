//
//  StickerInputView.swift
//  StickerInputView
//
//  Created by Bugen Zhao on 7/16/21.
//

import Foundation
import SwiftUI

enum StickerCategory: Hashable {
  case recent
  case prefix(String)
}

struct StickerInputView: View {
  @ObservedObject var model: ContentEditorModel

  @State var category: StickerCategory = .recent
  @AppStorage("recentStickers") var recentStickers = JSONRepr(inner: [String]())

  var currentStickers: [String] {
    switch category {
    case .recent: recentStickers.inner
    case let .prefix(prefix): stickerImageNames.filter { $0.starts(with: prefix) }
    }
  }

  @ViewBuilder
  var categoryPicker: some View {
    Picker("Category", selection: $category.animation()) {
      Image(systemName: "clock").tag(StickerCategory.recent)

      ForEach(stickerImageNamePrefixes, id: \.self) { p in
        Text(p.uppercased()).tag(StickerCategory.prefix(p))
      }
    }.pickerStyle(.segmented)
      .padding([.horizontal, .top], .small)
  }

  @ViewBuilder
  var stickerSelector: some View {
    let rows = [GridItem](repeating: .init(.fixed(50)), count: 4)

    Group {
      if currentStickers.isEmpty {
        Text("Empty")
          .foregroundColor(.secondary)
      } else {
        ScrollView(.horizontal) {
          LazyHGrid(rows: rows, spacing: 10) {
            ForEach(currentStickers, id: \.self) { name in
              Button(action: { insert(name: name) }) {
                Image(name)
                  .renderingMode(name.starts(with: "a") ? .template : .original)
                  .resizable()
                  .scaledToFit()
                  .background(name.starts(with: "dt") ? .white : .black.opacity(0.0))
                  .frame(height: 50)
              }
            }
          }.padding(.horizontal, .small)
        }.foregroundColor(.primary)
          .id("sticker-selector-\(category)") // reset scroll position
      }
    }
    .frame(height: 240) // 4 rows
    .onAppear {
      // Switch to first category if recent is empty.
      if recentStickers.inner.isEmpty, let first = stickerImageNamePrefixes.first {
        category = .prefix(first)
      }
    }
  }

  var body: some View {
    VStack(alignment: .center) {
      categoryPicker
      stickerSelector
    }
  }

  func insert(name: String) {
    let code = stickerImageNameToCode(name)
    model.insert(code)

    // Record recent stickers, up to 40.
    var newRecent = recentStickers.inner
    newRecent.removeAll { $0 == name }
    newRecent.insert(name, at: 0)
    newRecent.removeLast(max(0, newRecent.count - 40))
    withAnimation {
      recentStickers.inner = newRecent
    }
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
