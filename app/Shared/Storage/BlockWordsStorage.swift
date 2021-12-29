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
    if !words.contains(word) {
      words.insert(word, at: 0) // oops
    }
  }

  static func content(user: UserName, content: String) -> String {
    "\(BlockWord.fromUser(user))|\(content)"
  }
}
