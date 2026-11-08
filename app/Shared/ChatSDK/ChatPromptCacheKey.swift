//
//  ChatPromptCacheKey.swift
//  MNGA
//

import CryptoKit
import Foundation

enum ChatPromptCacheKey {
  private static let schemaVersion = "v1"

  static func make(namespace: String, prompt: String) -> String {
    let digest = SHA256.hash(data: Data(prompt.utf8))
      .prefix(20)
      .map { String(format: "%02x", $0) }
      .joined()
    let normalizedNamespace = namespace
      .lowercased()
      .map { $0.isLetter || $0.isNumber ? $0 : "-" }
      .reduce(into: "") { result, character in
        if character != "-" || result.last != "-" {
          result.append(character)
        }
      }
      .prefix(16)

    return "mnga-\(normalizedNamespace)-\(schemaVersion)-\(digest)"
  }
}
