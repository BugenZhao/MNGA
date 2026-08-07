//
//  ChatConfiguration.swift
//  MNGA
//

import Foundation

struct ChatAPIConfiguration: Equatable {
  static let defaultBaseURL = "https://api.openai.com/v1"
  static let defaultModel = "gpt-5.6-luna"

  let baseURL: URL
  let apiKey: String
  let model: String

  init(baseURL: String, apiKey: String, model: String) throws {
    self.baseURL = try Self.validate(baseURL: baseURL)

    let apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !apiKey.isEmpty else { throw ChatClientError.missingAPIKey }
    self.apiKey = apiKey

    let model = model.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !model.isEmpty else { throw ChatClientError.missingModel }
    self.model = model
  }

  static func validate(baseURL rawValue: String) throws -> URL {
    let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard var components = URLComponents(string: value),
          let scheme = components.scheme?.lowercased(),
          let host = components.host,
          !host.isEmpty,
          components.query == nil,
          components.fragment == nil
    else {
      throw ChatClientError.invalidBaseURL
    }

    let isLoopback = host == "localhost" || host == "127.0.0.1" || host == "::1"
    guard scheme == "https" || (scheme == "http" && isLoopback) else {
      throw ChatClientError.insecureBaseURL
    }

    while components.path.count > 1, components.path.hasSuffix("/") {
      components.path.removeLast()
    }
    guard let url = components.url else { throw ChatClientError.invalidBaseURL }
    return url
  }

  var chatCompletionsURL: URL {
    if baseURL.path.hasSuffix("/chat/completions") {
      return baseURL
    }
    if baseURL.path.hasSuffix("/v1") || baseURL.path.hasSuffix("/beta") {
      return baseURL.appending(path: "chat/completions")
    }
    return baseURL.appending(path: "v1/chat/completions")
  }

  var isDeepSeek: Bool {
    guard let host = baseURL.host?.lowercased() else { return false }
    return host == "deepseek.com" || host.hasSuffix(".deepseek.com")
  }

  var supportsStrictTools: Bool {
    !isDeepSeek || baseURL.path.split(separator: "/").contains("beta")
  }
}
