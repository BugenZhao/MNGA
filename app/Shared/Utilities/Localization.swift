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
}
