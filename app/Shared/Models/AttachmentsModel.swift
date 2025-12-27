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
    guard let attach = items.first(where: { previewURL.absoluteString.contains($0.url) })
    else { return nil }
    let url = URL(string: attach.url, relativeTo: URLs.attachmentBase)
    return url
  }

  var allImageURLs: [URL] {
    items
      .filter { $0.isImage }
      .compactMap { URL(string: $0.url, relativeTo: URLs.attachmentBase) }
  }
}
