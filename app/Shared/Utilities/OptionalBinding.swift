//
//  OptionalBinding.swift
//  OptionalBinding
//
//  Created by Bugen Zhao on 7/16/21.
//

import Foundation
import SwiftUI

func ?? <T>(lhs: Binding<T?>, rhs: T) -> Binding<T> {
  Binding(
    get: { lhs.wrappedValue ?? rhs },
    set: { lhs.wrappedValue = $0 },
  )
}
