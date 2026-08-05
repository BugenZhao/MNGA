//
//  AttachmentsModel.swift
//  AttachmentsModel
//
//  Created by Bugen Zhao on 8/23/21.
//

import Foundation
import SwiftUI

class AttachmentsModel: ObservableObject {
  var items: [Attachment]

  init(_ items: [Attachment] = []) {
    self.items = items
  }

  func attachmentURL(for previewURL: URL) -> URL? {
    items
      .compactMap { URLs.attachmentURL($0.url) }
      .first(where: { $0 == previewURL })
  }

  var allImageURLs: [URL] {
    items
      .filter(\.isImage)
      .compactMap { URLs.attachmentURL($0.url) }
  }
}
