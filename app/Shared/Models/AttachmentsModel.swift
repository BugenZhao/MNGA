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
    guard var attach = attachs.first(where: { previewURL.absoluteString.contains($0) })
      else { return nil }
    if !attach.contains("http") {
      attach = Constants.URL.attachmentBase + attach
    }
    return URL(string: attach)
  }
}
