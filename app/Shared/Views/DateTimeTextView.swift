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
    case detailed
    case timeAgo

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

  @Environment(\.inSnapshot) var inSnapshot

  @State var showDetailed: Bool

  static func build(timestamp: UInt64, switchable: Bool = true) -> Self {
    let showDetailed = switch PreferencesStorage.shared.postRowDateTimeStrategy {
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
    let date = Date(timeIntervalSince1970: TimeInterval(timestamp))

    let view = Group {
      if showDetailed || inSnapshot /* for snapshot, aleays use detailed time */ {
        Text(detailedTime(timestamp))
      } else {
        TimelineView(.everyMinute) { _ in
          // use system time instead of the date from timeline context, which is not accurate
          Text(timeAgo(date: date, relativeTo: Date()))
        }
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

struct DateTimeFooterView<Content: View>: View {
  let timestamp: UInt64
  let switchable: Bool

  let content: () -> Content

  init(timestamp: UInt64, switchable: Bool = true,
       @ViewBuilder content: @escaping () -> Content = { EmptyView() })
  {
    self.timestamp = timestamp
    self.switchable = switchable
    self.content = content
  }

  var body: some View {
    AdaptiveFooterView {
      content()
    } trailing: {
      DateTimeTextView.build(timestamp: timestamp, switchable: switchable)
    }
    .foregroundColor(.secondary)
    .font(.footnote)
  }
}
