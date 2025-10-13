//
//  BlockWordListView.swift
//  BlockWordListView
//
//  Created by Bugen Zhao on 7/18/21.
//

import Foundation
import SwiftUI

struct BlockWordListView: View {
  @StateObject var storage = BlockWordsStorage.shared
  @State var newWord = nil as BlockWord?
  @FocusState var focused: Bool

  func commitNewWord() {
    if let newWord, !newWord.word.isEmpty {
      storage.add(newWord)
      self.newWord = nil
      HapticUtils.play(type: .success)
    }
  }

  @ViewBuilder
  var list: some View {
    List {
      if newWord != nil {
        HStack {
          TextField(LocalizedStringKey("New word"), text: ($newWord ?? .init()).word)
            .onSubmit(commitNewWord)
            .focused($focused)
          Image(systemName: "pencil").foregroundColor(.secondary)
        }
      }

      ForEach(storage.words, id: \.word) { bw in
        HStack {
          if let user = bw.userName {
            Text(user)
            Spacer()
            Image(systemName: "person.crop.circle")
              .foregroundColor(.secondary)
          } else {
            Text(bw.word)
          }
        }
      }.onDelete { storage.words.remove(atOffsets: $0) }
    }
  }

  @ViewBuilder
  var addButton: some View {
    Button(action: {
      withAnimation {
        if let newWord, !newWord.word.isEmpty {
          storage.add(newWord)
        }
        newWord = .init()
        focused = true
      }
    }) {
      Label("Add Word", systemImage: "plus")
    }
  }

  var body: some View {
    Group {
      if storage.words.isEmpty, newWord == nil {
        PlaceholderView(icon: nil, title: "No Block Words")
      } else {
        list
      }
    }.mayInsetGroupedListStyle()
      .toolbar { ToolbarItem(placement: .mayNavigationBarTrailing) { addButton } }
      .navigationTitle("Block Contents")
  }
}

struct BlockWordListView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      BlockWordListView()
    }
  }
}
