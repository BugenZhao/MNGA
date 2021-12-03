//
//  View+RedactedIf.swift
//  View+RedactedIf
//
//  Created by Bugen Zhao on 8/17/21.
//

import Foundation
import SwiftUI

public extension View {
  func redacted(if cond: Bool, reason: RedactionReasons = .placeholder) -> some View {
    redacted(reason: cond ? reason : [])
  }
}
