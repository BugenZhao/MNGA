//
//  Misc.swift
//  NGA
//
//  Created by Bugen Zhao on 6/28/21.
//

import Foundation
import SwiftUI
import Logging

let logger: Logger = {
  var logger = Logger(label: "App")
  logger.logLevel = .info
  return logger
}();

public func withAnimation<Result>(_ animation: Animation? = .default, when condition: Bool, _ body: () throws -> Result) rethrows -> Result {
  if condition {
    return withAnimation { try! body() }
  } else {
    return try! body()
  }
}

public func extractQueryParams(query: String, param: String) -> String? {
  guard let regex = try? NSRegularExpression(pattern: "\(param)=(?<v>\\d+)", options: .caseInsensitive) else { return nil }
  if let match = regex.firstMatch(in: query, options: [], range: NSRange(query.startIndex..., in: query)) {
    if let range = Range(match.range(withName: "v"), in: query) {
      return String(query[range])
    }
  }
  return nil
}
