//
//  Misc.swift
//  NGA
//
//  Created by Bugen Zhao on 6/28/21.
//

import Foundation
import SwiftUI

public func withAnimation<Result>(_: Animation? = .default, when condition: Bool, _ body: () throws -> Result) rethrows -> Result {
  if condition {
    withAnimation { try! body() }
  } else {
    try! body()
  }
}

public func extractQueryParams(query: String, param: String) -> String? {
  guard let regex = try? NSRegularExpression(pattern: "\(param)=(?<v>[^&]+)", options: .caseInsensitive) else { return nil }
  if let match = regex.firstMatch(in: query, options: [], range: NSRange(query.startIndex..., in: query)) {
    if let range = Range(match.range(withName: "v"), in: query) {
      return String(query[range])
    }
  }
  return nil
}

struct BuildInfo {
  let version: String?
  let build: String?

  var debug: Bool {
    #if DEBUG
      true
    #else
      false
    #endif
  }

  static let current = BuildInfo(
    version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
    build: Bundle.main.infoDictionary?["CFBundleVersion"] as? String,
  )
}

extension BuildInfo: CustomStringConvertible {
  var description: String {
    "\(version ?? "??") (\(build ?? "?")\(debug ? "-DEBUG" : ""))"
  }
}

extension String {
  var trimmingWs: String {
    trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
