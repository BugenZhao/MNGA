//
//  DateTimeTextView.swift
//  NGA
//
//  Created by Bugen Zhao on 7/12/21.
//

import Foundation
import SwiftUI

struct DateTimeTextView: View {
  enum Strategy: Int, CaseIterable {
    case automatic
    case detailed, timeAgo

    var description: LocalizedStringKey {
      switch self {
      case .automatic:
        "Auto"
      case .detailed:
        "Detailed"
      case .timeAgo:
        "Time Ago"
      }
    }
  }

  let timestamp: UInt64
  let switchable: Bool

  @State var showDetailed: Bool

  static func build(timestamp: UInt64, switchable: Bool = true) -> Self {
    let showDetailed: Bool = switch PreferencesStorage.shared.postRowDateTimeStrategy {
    case .automatic:
      (Date().timeIntervalSince1970 - TimeInterval(timestamp)) > 30 * 24 * 3600
    case .detailed:
      true
    case .timeAgo:
      false
    }

    return Self(timestamp: timestamp, switchable: switchable, showDetailed: showDetailed)
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
        withAnimation { showDetailed.toggle() }
      }
    } else {
      view
    }
  }
}
