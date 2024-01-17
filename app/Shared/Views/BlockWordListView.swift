//
//  BlockWordListView.swift
//  BlockWordListView
//
//  Created by Bugen Zhao on 7/18/21.
//

import Foundation
import SwiftUI
import SwiftUIIntrospect

struct BlockWordListView: View {
  @StateObject var storage = BlockWordsStorage.shared
  @State var newWord = nil as BlockWord?

  func commitNewWord() {
    if let newWord, !newWord.word.isEmpty {
      storage.add(newWord)
      self.newWord = nil
    }
  }

  @ViewBuilder
  var list: some View {
    List {
      if newWord != nil {
        HStack {
          TextField(LocalizedStringKey("New word"), text: ($newWord ?? .init()).word, onCommit: commitNewWord)
            .introspect(.textField, on: .iOS(.v13, .v14, .v15, .v16, .v17)) {
              if newWord?.word.isEmpty == true {
                $0.becomeFirstResponder()
              }
            }
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
      }
    }) {
      Label("Add Word", systemImage: "plus.circle")
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
      .toolbarWithFix { ToolbarItem(placement: .mayNavigationBarTrailing) { addButton } }
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
