//
//  View+RedactedIf.swift
//  View+RedactedIf
//
//  Created by Bugen Zhao on 8/17/21.
//

import Foundation
import SwiftUI

extension View {
  public func redacted(if cond: Bool, reason: RedactionReasons = .placeholder) -> some View {
    self.redacted(reason: cond ? reason : [])
  }
}
