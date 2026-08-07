//
//  ChatConnectionTester.swift
//  MNGA
//

import Foundation

struct ChatConnectionTestReport {
  let statusCode: Int
  let model: String
  let responsePreview: String
  let inputTokens: Int?
  let outputTokens: Int?
}

final class ChatConnectionTester {
  private static let maximumErrorCharacters = 2_000
  private static let maximumPreviewCharacters = 300

  private let urlSession: URLSession

  init(urlSession: URLSession = .shared) {
    self.urlSession = urlSession
  }

  func test(configuration: ChatAPIConfiguration) async throws -> ChatConnectionTestReport {
    var request = URLRequest(url: configuration.chatCompletionsURL)
    request.httpMethod = "POST"
    request.timeoutInterval = 30
    request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.httpBody = try requestBody(configuration: configuration)

    let (data, response) = try await urlSession.data(for: request)
    try Task.checkCancellation()
    guard let httpResponse = response as? HTTPURLResponse else {
      throw ChatClientError.invalidResponse
    }

    guard (200 ..< 300).contains(httpResponse.statusCode) else {
      let apiError = try? JSONDecoder().decode(ConnectionTestAPIErrorEnvelope.self, from: data)
      let rawMessage = apiError?.error.message ?? String(decoding: data, as: UTF8.self)
      let message = redact(
        String(rawMessage.prefix(Self.maximumErrorCharacters)),
        secret: configuration.apiKey,
      )
      throw ChatClientError.httpStatus(
        code: httpResponse.statusCode,
        message: message,
        body: message,
      )
    }

    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    guard let response = try? decoder.decode(ConnectionTestAPIResponse.self, from: data),
          let content = response.choices.first?.message.content?
          .trimmingCharacters(in: .whitespacesAndNewlines),
          !content.isEmpty
    else {
      throw ChatClientError.invalidResponse
    }

    return ChatConnectionTestReport(
      statusCode: httpResponse.statusCode,
      model: response.model ?? configuration.model,
      responsePreview: String(content.prefix(Self.maximumPreviewCharacters)),
      inputTokens: response.usage?.resolvedInputTokens,
      outputTokens: response.usage?.resolvedOutputTokens,
    )
  }

  private func requestBody(configuration: ChatAPIConfiguration) throws -> Data {
    var body: [String: Any] = [
      "model": configuration.model,
      "messages": [[
        "role": "user",
        "content": "This is a connection test. Reply with exactly OK.",
      ]],
      "stream": false,
    ]
    if configuration.isDeepSeek {
      body["thinking"] = ["type": "disabled"]
    }
    return try JSONSerialization.data(
      withJSONObject: body,
      options: [.sortedKeys, .withoutEscapingSlashes],
    )
  }

  private func redact(_ value: String, secret: String) -> String {
    guard !secret.isEmpty else { return value }
    return value.replacingOccurrences(of: secret, with: "<redacted>")
  }
}

private struct ConnectionTestAPIErrorEnvelope: Decodable {
  struct APIError: Decodable {
    let message: String
  }

  let error: APIError
}

private struct ConnectionTestAPIResponse: Decodable {
  struct Choice: Decodable {
    struct Message: Decodable {
      let content: String?
    }

    let message: Message
  }

  struct Usage: Decodable {
    let promptTokens: Int?
    let inputTokens: Int?
    let completionTokens: Int?
    let outputTokens: Int?

    var resolvedInputTokens: Int? { promptTokens ?? inputTokens }
    var resolvedOutputTokens: Int? { completionTokens ?? outputTokens }
  }

  let model: String?
  let choices: [Choice]
  let usage: Usage?
}
