//
//  OpenAICompatibleChatClient.swift
//  MNGA
//

import Foundation

private actor PromptCacheCapabilityRegistry {
  static let shared = PromptCacheCapabilityRegistry()

  enum Capability {
    case explicit
    case automatic
    case none
  }

  private var capabilityByEndpointAndModel = [String: Capability]()

  func capability(for key: String) -> Capability? {
    capabilityByEndpointAndModel[key]
  }

  func setCapability(_ capability: Capability, for key: String) {
    capabilityByEndpointAndModel[key] = capability
  }
}

final class OpenAICompatibleChatClient: ChatClient {
  private let configuration: ChatAPIConfiguration
  private let urlSession: URLSession

  init(configuration: ChatAPIConfiguration, urlSession: URLSession = .shared) {
    self.configuration = configuration
    self.urlSession = urlSession
  }

  func stream(request: ChatRequest) -> AsyncThrowingStream<ChatStreamEvent, Error> {
    AsyncThrowingStream { continuation in
      let task = Task {
        do {
          let capabilityKey = "\(configuration.chatCompletionsURL.absoluteString)|\(configuration.model)"
          let knownCapability = await PromptCacheCapabilityRegistry.shared.capability(for: capabilityKey)

          if configuration.isDeepSeek {
            await PromptCacheCapabilityRegistry.shared.setCapability(.none, for: capabilityKey)
            try await perform(request: request, cacheMode: .none, continuation: continuation)
          } else if let knownCapability {
            try await perform(request: request, cacheMode: knownCapability, continuation: continuation)
          } else {
            try await discoverCapability(
              request: request,
              capabilityKey: capabilityKey,
              continuation: continuation,
            )
          }

          continuation.finish()
        } catch is CancellationError {
          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }

      continuation.onTermination = { @Sendable _ in task.cancel() }
    }
  }

  private func discoverCapability(
    request: ChatRequest,
    capabilityKey: String,
    continuation: AsyncThrowingStream<ChatStreamEvent, Error>.Continuation,
  ) async throws {
    do {
      try await perform(request: request, cacheMode: .explicit, continuation: continuation)
      await PromptCacheCapabilityRegistry.shared.setCapability(.explicit, for: capabilityKey)
    } catch let error as ChatClientError where error.indicatesUnsupportedCacheExtensions {
      do {
        try await perform(request: request, cacheMode: .automatic, continuation: continuation)
        await PromptCacheCapabilityRegistry.shared.setCapability(.automatic, for: capabilityKey)
      } catch let automaticError as ChatClientError where automaticError.indicatesUnsupportedCacheExtensions {
        await PromptCacheCapabilityRegistry.shared.setCapability(.none, for: capabilityKey)
        try await perform(request: request, cacheMode: .none, continuation: continuation)
      }
    }
  }

  private func perform(
    request: ChatRequest,
    cacheMode: PromptCacheCapabilityRegistry.Capability,
    continuation: AsyncThrowingStream<ChatStreamEvent, Error>.Continuation,
  ) async throws {
    var urlRequest = URLRequest(url: configuration.chatCompletionsURL)
    urlRequest.httpMethod = "POST"
    urlRequest.timeoutInterval = 120
    urlRequest.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
    urlRequest.httpBody = try requestBody(for: request, cacheMode: cacheMode)

    let (bytes, response) = try await urlSession.bytes(for: urlRequest)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw ChatClientError.invalidResponse
    }

    guard (200 ..< 300).contains(httpResponse.statusCode) else {
      let data = try await collect(bytes: bytes, limit: 128 * 1024)
      let body = String(decoding: data, as: UTF8.self)
      let apiError = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data)
      throw ChatClientError.httpStatus(
        code: httpResponse.statusCode,
        message: apiError?.error.message ?? body,
        body: body,
      )
    }

    var lineBuffer = Data()
    var eventDataLines = [String]()
    var receivedOutput = false
    var reachedDone = false

    func processEvent() throws {
      guard !eventDataLines.isEmpty else { return }
      let payload = eventDataLines.joined(separator: "\n")
      eventDataLines.removeAll(keepingCapacity: true)

      if payload == "[DONE]" {
        reachedDone = true
        return
      }

      let parsed = try decode(payload: payload)
      for delta in parsed.textDeltas where !delta.isEmpty {
        receivedOutput = true
        continuation.yield(.textDelta(delta))
      }
      for delta in parsed.reasoningDeltas where !delta.isEmpty {
        receivedOutput = true
        continuation.yield(.reasoningDelta(delta))
      }
      for delta in parsed.toolCallDeltas {
        receivedOutput = true
        continuation.yield(.toolCallDelta(delta))
      }
      if let usage = parsed.usage {
        continuation.yield(.usage(usage))
      }
    }

    func processLine(_ line: String) throws {
      if line.isEmpty {
        try processEvent()
      } else if line.hasPrefix("data:") {
        eventDataLines.append(String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces))
      } else if line.first == "{" {
        eventDataLines.append(line)
        try processEvent()
      }
    }

    for try await byte in bytes {
      try Task.checkCancellation()
      if byte == 0x0A {
        let line = String(decoding: lineBuffer, as: UTF8.self)
        lineBuffer.removeAll(keepingCapacity: true)
        try processLine(line)
        if reachedDone { break }
      } else if byte != 0x0D {
        lineBuffer.append(byte)
      }
    }

    if !reachedDone, !lineBuffer.isEmpty {
      try processLine(String(decoding: lineBuffer, as: UTF8.self))
    }
    if !reachedDone {
      try processEvent()
    }
    guard receivedOutput else { throw ChatClientError.emptyResponse }
  }

  private func requestBody(
    for request: ChatRequest,
    cacheMode: PromptCacheCapabilityRegistry.Capability,
  ) throws -> Data {
    let systemContent: Any
    if cacheMode == .explicit {
      systemContent = [[
        "type": "text",
        "text": request.context.stablePrompt,
        "prompt_cache_breakpoint": ["mode": "explicit"],
      ]]
    } else {
      systemContent = request.context.stablePrompt
    }

    var messages: [[String: Any]] = [[
      "role": "system",
      "content": systemContent,
    ]]
    messages.append(contentsOf: request.messages.map { message in
      var encoded: [String: Any] = ["role": message.role.rawValue]
      encoded["content"] = message.content ?? NSNull()
      if let reasoningContent = message.reasoningContent {
        encoded["reasoning_content"] = reasoningContent
      }

      if !message.toolCalls.isEmpty {
        encoded["tool_calls"] = message.toolCalls.map { call in
          [
            "id": call.id,
            "type": "function",
            "function": [
              "name": call.name,
              "arguments": call.arguments,
            ],
          ]
        }
      }
      if let toolCallID = message.toolCallID {
        encoded["tool_call_id"] = toolCallID
      }
      return encoded
    })

    var body: [String: Any] = [
      "model": configuration.model,
      "messages": messages,
      "stream": true,
    ]

    if !request.tools.isEmpty {
      body["tools"] = request.tools.map { tool in
        [
          "type": "function",
          "function": [
            "name": tool.name,
            "description": tool.description,
            "strict": configuration.supportsStrictTools,
            "parameters": tool.parameters,
          ],
        ]
      }
      if !configuration.isDeepSeek {
        body["parallel_tool_calls"] = false
      }
    }

    if cacheMode != .none {
      body["prompt_cache_key"] = request.context.id
    }
    if cacheMode == .explicit {
      body["prompt_cache_options"] = ["mode": "explicit", "ttl": "30m"]
    }
    if cacheMode == .explicit || configuration.isDeepSeek {
      body["stream_options"] = ["include_usage": true]
    }

    return try JSONSerialization.data(
      withJSONObject: body,
      options: [.sortedKeys, .withoutEscapingSlashes],
    )
  }

  private func collect(bytes: URLSession.AsyncBytes, limit: Int) async throws -> Data {
    var data = Data()
    data.reserveCapacity(min(limit, 16 * 1024))
    for try await byte in bytes {
      if data.count >= limit { break }
      data.append(byte)
    }
    return data
  }

  private func decode(payload: String) throws -> ParsedPayload {
    let data = Data(payload.utf8)
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase

    if let envelope = try? decoder.decode(APIErrorEnvelope.self, from: data) {
      throw ChatClientError.httpStatus(code: 200, message: envelope.error.message, body: payload)
    }

    let response = try decoder.decode(APIChatResponse.self, from: data)
    var textDeltas = [String]()
    var reasoningDeltas = [String]()
    var toolCallDeltas = [ChatToolCallDelta]()
    for choice in response.choices {
      let content = choice.delta ?? choice.message
      if let text = content?.content {
        textDeltas.append(text)
      }
      if let reasoning = content?.reasoningContent {
        reasoningDeltas.append(reasoning)
      }
      for (offset, call) in (content?.toolCalls ?? []).enumerated() {
        toolCallDeltas.append(ChatToolCallDelta(
          index: call.index ?? offset,
          id: call.id,
          name: call.function?.name,
          argumentsDelta: call.function?.arguments,
        ))
      }
    }
    return ParsedPayload(
      textDeltas: textDeltas,
      reasoningDeltas: reasoningDeltas,
      toolCallDeltas: toolCallDeltas,
      usage: response.usage?.chatUsage,
    )
  }
}

private struct ParsedPayload {
  let textDeltas: [String]
  let reasoningDeltas: [String]
  let toolCallDeltas: [ChatToolCallDelta]
  let usage: ChatUsage?
}

private struct APIErrorEnvelope: Decodable {
  struct APIError: Decodable {
    let message: String
  }

  let error: APIError
}

private struct APIChatResponse: Decodable {
  struct Choice: Decodable {
    struct Content: Decodable {
      let content: String?
      let reasoningContent: String?
      let toolCalls: [ToolCall]?
    }

    struct ToolCall: Decodable {
      struct Function: Decodable {
        let name: String?
        let arguments: String?
      }

      let index: Int?
      let id: String?
      let function: Function?
    }

    let delta: Content?
    let message: Content?
  }

  struct Usage: Decodable {
    struct TokenDetails: Decodable {
      let cachedTokens: Int?
      let cacheWriteTokens: Int?
    }

    let promptTokens: Int?
    let inputTokens: Int?
    let completionTokens: Int?
    let outputTokens: Int?
    let promptTokensDetails: TokenDetails?
    let inputTokensDetails: TokenDetails?
    let promptCacheHitTokens: Int?
    let promptCacheMissTokens: Int?

    var chatUsage: ChatUsage {
      let details = promptTokensDetails ?? inputTokensDetails
      return ChatUsage(
        inputTokens: promptTokens ?? inputTokens ?? 0,
        cachedInputTokens: details?.cachedTokens ?? promptCacheHitTokens ?? 0,
        cacheWriteTokens: details?.cacheWriteTokens ?? 0,
        outputTokens: completionTokens ?? outputTokens ?? 0,
      )
    }
  }

  let choices: [Choice]
  let usage: Usage?
}
