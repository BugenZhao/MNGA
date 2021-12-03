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

  @Published var selected: NSRange
  @Published var text: String

  @Published var image: Data? = nil
  @Published var showingImagePicker = false

  @objc func showSticker() {
    showing = .sticker
  }

  init(initialText: String) {
    _text = .init(initialValue: initialText)
    _selected = .init(initialValue: NSRange(location: (initialText as NSString).length, length: 0))
  }

  private func appendTag(_ tag: String) {
    let range = Range(selected, in: text)!
    let selectedText = text[range]
    text.replaceSubrange(range, with: "[\(tag)]\(selectedText)[/\(tag)]")
    let newLocation = selected.location + (tag as NSString).length + 2
    selected = NSRange(location: newLocation, length: selected.length)
  }

  @objc func appendBold() {
    appendTag("b")
  }

  @objc func appendDel() {
    appendTag("del")
  }

  @objc func showImagePicker() {
    showingImagePicker = true
  }

  func insert(_ string: String) {
    let range = Range(selected, in: text)!
    text.replaceSubrange(range, with: string)
    let newLocation = selected.location + (string as NSString).length
    selected = NSRange(location: newLocation, length: 0)
  }
}
