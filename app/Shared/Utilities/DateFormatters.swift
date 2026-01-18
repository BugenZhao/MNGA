//
//  DateFormatters.swift
//  NGA
//
//  Created by Bugen Zhao on 6/28/21.
//

import Foundation

private let timeAgoFormatter = RelativeDateTimeFormatter()

public func timeAgo(_ timestamp: UInt64) -> String {
  let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
  return timeAgo(date: date)
}

public func timeAgo(date: Date) -> String {
  timeAgo(date: date, relativeTo: Date())
}

public func timeAgo(date: Date, relativeTo: Date) -> String {
  // Clamp future timestamps to avoid showing "in X seconds" when clocks drift.
  let clampedDate = Swift.min(date, relativeTo)
  let delta = relativeTo.timeIntervalSince(clampedDate)

  if delta < 60 {
    return "Just now".localized
  }

  return timeAgoFormatter.localizedString(for: clampedDate, relativeTo: relativeTo)
}

private let detailedFormatter: DateFormatter = {
  let f = DateFormatter()
  f.dateStyle = .long
  f.timeStyle = .short
  return f
}()

public func detailedTime(_ timestamp: UInt64) -> String {
  let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
  let dateString = detailedFormatter.string(from: date)
  return dateString
}

public func currentDateString() -> String {
  ISO8601DateFormatter.string(from: Date(), timeZone: .current, formatOptions: [.withFullDate, .withDashSeparatorInDate])
}
