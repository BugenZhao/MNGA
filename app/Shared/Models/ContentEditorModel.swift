//
//  ContentEditorModel.swift
//  MNGA
//
//  Created by Bugen Zhao on 2021/10/20.
//

import AlertToast
import Foundation
import SwiftUI
import SwiftUIX

class ContentEditorModel: ObservableObject {
  enum Panel {
    case sticker
    case none
  }

  private let keyboard = Keyboard.main

  @Published var showing = Panel.none {
    didSet { if showing != .none { keyboard.dismiss() } }
  }

  @Published var selection = AttributedTextSelection()
  @Published var attributedText: AttributedString

  @Published var image: Data? = nil
  @Published var showingImagePicker = false

  var plainText: String {
    String(attributedText.characters)
  }

  func showSticker() {
    showing = .sticker
  }

  init(initialText: String) {
    attributedText = AttributedString(initialText)
    selection = AttributedTextSelection(insertionPoint: attributedText.endIndex)
  }

  private func appendTag(_ tag: String) {
    let tagLength = tag.utf16.count + 2 // "[tag]"
    let indices = selection.indices(in: attributedText)

    switch indices {
    case let .insertionPoint(index):
      // Insert tags at cursor position
      attributedText.insert(AttributedString("[\(tag)][/\(tag)]"), at: index)

      // Position cursor between the tags
      let newIndex = attributedText.index(index, offsetByCharacters: tagLength)
      selection = AttributedTextSelection(insertionPoint: newIndex)

    case let .ranges(rangeSet):
      // Handle selection ranges - use first range for simplicity
      if let firstRange = rangeSet.ranges.first {
        // TODO: not correct! index will be invalidated after mutation
        attributedText.insert(AttributedString("[/\(tag)]"), at: firstRange.upperBound)
        attributedText.insert(AttributedString("[\(tag)]"), at: firstRange.lowerBound)

        // Update selection to highlight the content between tags
        let tagLength = tag.utf16.count + 2 // "[tag]"
        let newStart = firstRange.lowerBound
        let newEnd = attributedText.index(firstRange.upperBound, offsetByCharacters: tagLength + 1)
        selection = AttributedTextSelection(range: newStart ..< newEnd)
      }
    }
  }

  func appendBold() {
    appendTag("b")
  }

  func appendDel() {
    appendTag("del")
  }

  func showImagePicker() {
    showingImagePicker = true
  }

  func insert(_ string: String) {
    let indices = selection.indices(in: attributedText)
    let insertAttributed = AttributedString(string)

    switch indices {
    case let .insertionPoint(index):
      attributedText.insert(insertAttributed, at: index)
      let newIndex = attributedText.index(index, offsetByCharacters: string.utf16.count)
      selection = AttributedTextSelection(insertionPoint: newIndex)

    case let .ranges(rangeSet):
      if let firstRange = rangeSet.ranges.first {
        attributedText.replaceSubrange(firstRange, with: insertAttributed)
        let newIndex = attributedText.index(firstRange.lowerBound, offsetByCharacters: string.utf16.count)
        selection = AttributedTextSelection(insertionPoint: newIndex)
      }
    }
  }
}
