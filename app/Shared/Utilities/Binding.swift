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
  var w: Value {
    get { self.wrappedValue }
    nonmutating set { self.wrappedValue = newValue }
  }
}
