//
//  Localization.swift
//  MNGA
//
//  Created by Bugen Zhao on 2021/10/22.
//

import Foundation
import SwiftUI

extension LocalizedStringKey {
  var stringKey: String {
    let description = "\(self)"

    let components = description.components(separatedBy: "key: \"")
      .map { $0.components(separatedBy: "\",") }

    return components.dropFirst().first?.first ?? "??"
  }
}

extension String {
  var localized: String {
    NSLocalizedString(self, comment: "")
  }

  var errorLocalized: String {
    let tokens = split(separator: "|", maxSplits: 2).map(String.init)
    if tokens.count != 2 {
      return localized
    }
    return "\(tokens[0].localized): \(tokens[1].errorMessageLocalized)"
  }

  /// Localizes a message from the logic layer, such as `The image is too large to upload (9)`,
  /// while keeping the trailing error code. Messages from NGA have no translation and stay as is.
  private var errorMessageLocalized: String {
    guard let range = range(of: #" \([^()]*\)$"#, options: .regularExpression) else {
      return localized
    }
    return String(self[..<range.lowerBound]).localized + self[range.lowerBound...]
  }
}
