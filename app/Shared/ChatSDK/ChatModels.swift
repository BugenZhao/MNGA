//
//  ChatModels.swift
//  MNGA
//

import Foundation

struct ChatMessage: Identifiable, Codable, Equatable {
  enum Role: String, Codable {
    case user
    case assistant
  }

  enum DeliveryState: String, Codable {
    case complete
    case streaming
    case failed
    case cancelled
  }

  let id: UUID
  let role: Role
  var content: String
  var deliveryState: DeliveryState
  let createdAt: Date

  init(
    id: UUID = UUID(),
    role: Role,
    content: String,
    deliveryState: DeliveryState = .complete,
    createdAt: Date = Date(),
  ) {
    self.id = id
    self.role = role
    self.content = content
    self.deliveryState = deliveryState
    self.createdAt = createdAt
  }
}

struct ChatContextCoverage: Hashable {
  let includedItems: Int
  let loadedItems: Int
  let totalItems: Int
  let isTruncated: Bool
}

struct ChatContext: Identifiable, Hashable {
  let id: String
  let title: String
  let stablePrompt: String
  let coverage: ChatContextCoverage?

  init(
    namespace: String,
    title: String,
    stablePrompt: String,
    coverage: ChatContextCoverage? = nil,
  ) {
    id = ChatPromptCacheKey.make(namespace: namespace, prompt: stablePrompt)
    self.title = title
    self.stablePrompt = stablePrompt
    self.coverage = coverage
  }
}

struct ChatToolCall: Equatable {
  let id: String
  let name: String
  let arguments: String
}

struct ChatToolActivity: Identifiable, Equatable {
  enum State: Equatable {
    case running
    case succeeded
    case failed
    case cancelled
  }

  let id: UUID
  let assistantMessageID: UUID
  let callID: String
  let toolName: String
  let displayName: String
  let arguments: String
  let startedAt: Date
  var output: String?
  var completedAt: Date?
  var state: State
  var reuseCount = 0

  var duration: TimeInterval? {
    completedAt?.timeIntervalSince(startedAt)
  }

  var failureDescription: String? {
    guard state == .failed,
          let output,
          let data = output.data(using: .utf8),
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
      return nil
    }
    return (object["error"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

struct ChatToolCallDelta {
  let index: Int
  let id: String?
  let name: String?
  let argumentsDelta: String?
}

struct ChatModelMessage {
  enum Role: String {
    case user
    case assistant
    case tool
  }

  let role: Role
  let content: String?
  let reasoningContent: String?
  let toolCalls: [ChatToolCall]
  let toolCallID: String?

  static func user(_ content: String) -> Self {
    Self(role: .user, content: content, reasoningContent: nil, toolCalls: [], toolCallID: nil)
  }

  static func assistant(
    content: String?,
    reasoningContent: String? = nil,
    toolCalls: [ChatToolCall] = [],
  ) -> Self {
    Self(
      role: .assistant,
      content: content,
      reasoningContent: reasoningContent,
      toolCalls: toolCalls,
      toolCallID: nil,
    )
  }

  static func tool(callID: String, content: String) -> Self {
    Self(role: .tool, content: content, reasoningContent: nil, toolCalls: [], toolCallID: callID)
  }
}

struct ChatRequest {
  let context: ChatContext
  let messages: [ChatModelMessage]
  let tools: [ChatToolDefinition]
}

struct ChatUsage: Equatable {
  let inputTokens: Int
  let cachedInputTokens: Int
  let cacheWriteTokens: Int
  let outputTokens: Int
}

enum ChatStreamEvent {
  case textDelta(String)
  case reasoningDelta(String)
  case toolCallDelta(ChatToolCallDelta)
  case usage(ChatUsage)
}

protocol ChatClient {
  func stream(request: ChatRequest) -> AsyncThrowingStream<ChatStreamEvent, Error>
}

enum ChatClientError: LocalizedError {
  case invalidBaseURL
  case insecureBaseURL
  case missingAPIKey
  case missingModel
  case invalidResponse
  case emptyResponse
  case toolRoundLimitExceeded
  case httpStatus(code: Int, message: String, body: String)

  var errorDescription: String? {
    switch self {
    case .invalidBaseURL:
      "The Base API URL is invalid.".localized
    case .insecureBaseURL:
      "The Base API URL must use HTTPS unless it points to localhost.".localized
    case .missingAPIKey:
      "Configure an API key in Settings before starting a chat.".localized
    case .missingModel:
      "Configure a model in Settings before starting a chat.".localized
    case .invalidResponse:
      "The chat service returned an invalid response.".localized
    case .emptyResponse:
      "The chat service returned an empty response.".localized
    case .toolRoundLimitExceeded:
      "The chat stopped because it exceeded the tool-call limit.".localized
    case let .httpStatus(code, message, _):
      if message.isEmpty {
        String(format: "Chat request failed with HTTP %lld.".localized, code)
      } else {
        message
      }
    }
  }

  var indicatesUnsupportedCacheExtensions: Bool {
    guard case let .httpStatus(code, message, body) = self, code == 400 || code == 422 else {
      return false
    }

    let details = "\(message) \(body)".lowercased()
    return details.contains("prompt_cache") ||
      details.contains("cache breakpoint") ||
      details.contains("content must be a string") ||
      details.contains("unknown parameter") ||
      details.contains("unrecognized field") ||
      details.contains("extra inputs") ||
      details.contains("extra_forbidden") ||
      details.contains("unexpected keyword")
  }
}
