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
      set: { intBinding.wrappedValue = TInt($0) },
    )
  }

  static func convert<TFloat, TInt>(_ floatBinding: Binding<TFloat>) -> Binding<TInt>
    where TFloat: BinaryFloatingPoint,
    TInt: BinaryInteger
  {
    Binding<TInt>(
      get: { TInt(floatBinding.wrappedValue) },
      set: { floatBinding.wrappedValue = TFloat($0) },
    )
  }
}

extension TextSelection {
  func fits(in text: String) -> Bool {
    switch indices {
    case let .selection(range):
      range.upperBound <= text.endIndex
    case let .multiSelection(ranges):
      ranges.ranges.allSatisfy { $0.upperBound <= text.endIndex }
    @unknown default:
      true
    }
  }
}

extension Binding<TextSelection?> {
  /// Hides a selection that extends past the end of `text`.
  ///
  /// The text can shrink without the selection following it, for example when a binding clamps the
  /// input or an IME composition commits on focus loss. On iOS 18, SwiftUI then traps with "String
  /// index is out of bounds" while applying the selection to the text field or text editor.
  func fitting(_ text: Binding<String>) -> Binding<TextSelection?> {
    Binding(
      get: {
        guard let selection = wrappedValue, selection.fits(in: text.wrappedValue) else { return nil }
        return selection
      },
      set: { wrappedValue = $0 },
    )
  }
}
