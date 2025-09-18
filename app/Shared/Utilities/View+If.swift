//
//  View+If.swift
//  View+RedactedIf
//
//  Created by Bugen Zhao on 8/17/21.
//

import Foundation
import SwiftUI

public extension View {
  func `if`(_ cond: @autoclosure () -> Bool, content: (Self) -> some View) -> some View {
    Group {
      if cond() {
        content(self)
      } else {
        self
      }
    }
  }
}

public extension View {
  func redacted(if cond: @autoclosure () -> Bool, reason: RedactionReasons = .placeholder) -> some View {
    redacted(reason: cond() ? reason : [])
  }
}
