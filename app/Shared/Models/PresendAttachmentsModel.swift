//
//  PresendAttachmentsModel.swift
//  PresendAttachmentsModel
//
//  Created by Bugen Zhao on 2021/9/14.
//

import Foundation
import SwiftUI
import SwiftUIX

class PresendAttachmentsModel: ObservableObject {
  private var attachs = [String: Data]()

  func add(url: String, data: Data) {
    attachs[url] = data
  }

  func image(for previewURL: URL) -> AppKitOrUIKitImage? {
    guard let data = attachs.first(where: { previewURL.absoluteString.contains($0.key) })?.value
    else { return nil }
    return AppKitOrUIKitImage(data: data)
  }
}
