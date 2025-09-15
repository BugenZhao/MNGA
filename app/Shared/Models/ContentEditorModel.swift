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

  @Published var text: String
  @Published var selection: TextSelection?

  @Published var image: Data? = nil
  @Published var showingImagePicker = false

  func showSticker() {
    showing = .sticker
  }

  init(initialText: String) {
    text = initialText
    selection = TextSelection(insertionPoint: text.endIndex)
  }

  func insert(_ string: String) {
    let selection = selection ?? TextSelection(insertionPoint: text.endIndex)
    guard case let .selection(range) = selection.indices else { return }
    let prefixLength = text.distance(from: text.startIndex, to: range.lowerBound)

    text.replaceSubrange(range, with: string)

    let insertionPoint = text.index(text.startIndex, offsetBy: prefixLength + string.count)
    self.selection = TextSelection(insertionPoint: insertionPoint)

    // Sometimes it just doesn't work if we set string and selection at the same time...
    // DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
    //   if let ip = insertionPoint.samePosition(in: self.text) {
    //     self.selection = TextSelection(insertionPoint: ip)
    //   }
    // }
  }

  private func appendTag(_ tag: String) {
    let open = "[\(tag)]"
    let close = "[/\(tag)]"

    let selection = selection ?? TextSelection(insertionPoint: text.endIndex)
    guard case let .selection(range) = selection.indices else { return }
    let prefixLength = text.distance(from: text.startIndex, to: range.lowerBound)
    let distance = text.distance(from: range.lowerBound, to: range.upperBound)

    text.insert(contentsOf: open, at: range.lowerBound)
    text.insert(contentsOf: close, at: text.index(text.startIndex, offsetBy: prefixLength + open.count + distance))

    // Note: never reuse index after mutation! if there's re-allocation, the index is invalid!
    let insertionPoint = text.index(text.startIndex, offsetBy: prefixLength + open.count + distance)
    self.selection = TextSelection(insertionPoint: insertionPoint)

    // Sometimes it just doesn't work if we set string and selection at the same time...
    // DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
    //   if let ip = insertionPoint.samePosition(in: self.text) {
    //     self.selection = TextSelection(insertionPoint: ip)
    //   }
    // }
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
}
