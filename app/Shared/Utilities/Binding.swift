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
    get { wrappedValue }
    nonmutating set { self.wrappedValue = newValue }
  }
}

extension Binding {
  static func convert<TInt, TFloat>(_ intBinding: Binding<TInt>) -> Binding<TFloat>
    where TInt: BinaryInteger,
    TFloat: BinaryFloatingPoint
  {
    Binding<TFloat>(
      get: { TFloat(intBinding.wrappedValue) },
      set: { intBinding.wrappedValue = TInt($0) }
    )
  }

  static func convert<TFloat, TInt>(_ floatBinding: Binding<TFloat>) -> Binding<TInt>
    where TFloat: BinaryFloatingPoint,
    TInt: BinaryInteger
  {
    Binding<TInt>(
      get: { TInt(floatBinding.wrappedValue) },
      set: { floatBinding.wrappedValue = TFloat($0) }
    )
  }
}
