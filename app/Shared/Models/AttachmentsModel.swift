//
//  AttachmentsModel.swift
//  AttachmentsModel
//
//  Created by Bugen Zhao on 8/23/21.
//

import Foundation
import SwiftUI

class AttachmentsModel: ObservableObject {
  private var attachs = Set<String>()

  func add(_ item: String) {
    self.attachs.insert(item)
  }

  func attachmentURL(for previewURL: URL) -> URL? {
    guard let attach = attachs.first(where: { previewURL.absoluteString.contains($0) })
      else { return nil }
    let url = URL(string: "\(attach)", relativeTo: URLs.attachmentBase)
    logger.debug("attachment: \(url as Any?) for \(previewURL)")
    return url
  }
}
