//
//  DateFormatters.swift
//  NGA
//
//  Created by Bugen Zhao on 6/28/21.
//

import Foundation

fileprivate let timeAgoFormatter = RelativeDateTimeFormatter()

public func timeAgo(_ timestamp: UInt64) -> String {
  let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
  let dateString = timeAgoFormatter.localizedString(for: date, relativeTo: Date())
  return dateString
}

fileprivate let detailedFormatter: DateFormatter = {
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
