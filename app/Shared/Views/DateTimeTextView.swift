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

  @State var showDetailed = false

  init(timestamp: UInt64, switchable: Bool = true) {
    self.timestamp = timestamp
    self.switchable = switchable
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
