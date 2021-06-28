//
//  TimeAgo.swift
//  NGA
//
//  Created by Bugen Zhao on 6/28/21.
//

import Foundation

fileprivate let formatter = RelativeDateTimeFormatter()

public func timeago(_ timestamp: UInt64) -> String {
  let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
  let dateString = formatter.localizedString(for: date, relativeTo: Date())
  return dateString
}
