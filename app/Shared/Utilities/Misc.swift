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
    return withAnimation { try! body() }
  } else {
    return try! body()
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

func getVersionWithBuild() -> String {
  let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
  let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String

  return "\(version ?? "??") (\(build ?? "?"))"
}
