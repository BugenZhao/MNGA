//
//  BlockWordsStorage.swift
//  BlockWordsStorage
//
//  Created by Bugen Zhao on 7/18/21.
//

import Combine
import Foundation
import SwiftUI

class BlockWordsStorage: ObservableObject {
  static let shared = BlockWordsStorage()

  @AppStorage("blockWords") var words = [BlockWord]()

  func blocked(_ content: String) -> Bool {
    words.contains { content.contains($0.word) }
  }

  func blocked(user: UserName) -> Bool {
    words.contains(BlockWord.fromUser(user))
  }

  func add(_ word: BlockWord) {
    withAnimation {
      if !words.contains(word) {
        words.insert(word, at: 0) // oops
      }
    }
  }

  func remove(_ word: BlockWord) {
    withAnimation {
      words.removeAll { $0 == word }
    }
  }

  func toggle(user: UserName) {
    let word = BlockWord.fromUser(user)

    if blocked(user: user) {
      remove(word)
    } else {
      add(word)
    }
  }

  static func content(user: UserName, content: String) -> String {
    "\(BlockWord.fromUser(user))|\(content)"
  }
}
