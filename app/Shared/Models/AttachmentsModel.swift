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
    let url = URL(string: "\(attach)", relativeTo: URLs.attachmentBase)
    logger.debug("attachment: \(url as Any?) for \(previewURL)")
    return url
  }
}
