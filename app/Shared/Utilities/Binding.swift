//
//  Binding.swift
//  MNGA
//
//  Created by Bugen Zhao on 2021/10/24.
//

import Foundation
import SwiftUI

extension Binding {
  @inlinable
  static func local(_ initialValue: Value) -> Self {
    var value = initialValue
    return .init(get: { value }, set: { value = $0 })
  }

  @inlinable
  var w: Value {
    self.wrappedValue
  }
}
