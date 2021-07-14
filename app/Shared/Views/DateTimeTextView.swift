//
//  DateTimeTextView.swift
//  NGA
//
//  Created by Bugen Zhao on 7/12/21.
//

import Foundation
import SwiftUI

struct DateTimeTextView: View {
  let timestamp: UInt64
  let switchable: Bool

  @State var showDetailed: Bool

  static func build(timestamp: UInt64, switchable: Bool = true) -> Self {
    let showDetailed = (Date().timeIntervalSince1970 - TimeInterval(timestamp)) > 30 * 24 * 3600
    return Self.init(timestamp: timestamp, switchable: switchable, showDetailed: showDetailed)
  }

  var body: some View {
    let view = Group {
      if showDetailed {
        Text(detailedTime(timestamp))
      } else {
        Text(timeAgo(timestamp))
      }
    }

    if switchable {
      view.onTapGesture {
        withAnimation { self.showDetailed.toggle() }
      }
    } else {
      view
    }
  }
}
