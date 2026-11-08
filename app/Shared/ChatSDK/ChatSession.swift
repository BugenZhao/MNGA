//
//  ChatSession.swift
//  MNGA
//

import Foundation

@MainActor
final class ChatSession: ObservableObject {
  typealias ClientFactory = () throws -> any ChatClient

  @Published private(set) var messages = [ChatMessage]()
  @Published private(set) var isStreaming = false
  @Published private(set) var errorMessage: String?
  @Published private(set) var usage: ChatUsage?
  @Published private(set) var toolActivities = [ChatToolActivity]()

  let context: ChatContext

  private let clientFactory: ClientFactory
  private let toolRegistry: ChatToolRegistry
  private var modelMessages = [ChatModelMessage]()
  private var streamingTask: Task<Void, Never>?
  private var activeGenerationID: UUID?
  private var activeModelMessageCheckpoint: Int?

  init(
    context: ChatContext,
    toolRegistry: ChatToolRegistry = .empty,
    clientFactory: @escaping ClientFactory,
  ) {
    self.context = context
    self.toolRegistry = toolRegistry
    self.clientFactory = clientFactory
  }

  var canRetry: Bool {
    guard !isStreaming, let last = messages.last else { return false }
    return last.role == .user || last.deliveryState == .failed || last.deliveryState == .cancelled
  }

  func send(_ rawText: String) {
    let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty, !isStreaming else { return }

    removeIncompleteAssistantIfNeeded()
    messages.append(ChatMessage(role: .user, content: text))
    modelMessages.append(.user(text))
    generateAssistantResponse()
  }

  func retry() {
    guard canRetry else { return }
    removeIncompleteAssistantIfNeeded()
    generateAssistantResponse()
  }

  func cancel() {
    guard isStreaming else { return }
    streamingTask?.cancel()
    streamingTask = nil
    if let checkpoint = activeModelMessageCheckpoint {
      rollbackModelMessages(to: checkpoint)
    }
    activeGenerationID = nil
    activeModelMessageCheckpoint = nil
    cancelRunningToolActivities()
    isStreaming = false
    if let index = messages.indices.last, messages[index].deliveryState == .streaming {
      messages[index].deliveryState = .cancelled
    }
  }

  func reset() {
    cancel()
    messages.removeAll()
    modelMessages.removeAll()
    errorMessage = nil
    usage = nil
    toolActivities.removeAll()
  }

  private func removeIncompleteAssistantIfNeeded() {
    guard let last = messages.last, last.role == .assistant, last.deliveryState != .complete else { return }
    messages.removeLast()
    toolActivities.removeAll { $0.assistantMessageID == last.id }
  }

  private func generateAssistantResponse() {
    guard !isStreaming, messages.last?.role == .user else { return }

    let modelMessageCheckpoint = modelMessages.count
    let generationID = UUID()
    let assistantID = UUID()
    messages.append(ChatMessage(
      id: assistantID,
      role: .assistant,
      content: "",
      deliveryState: .streaming,
    ))
    errorMessage = nil
    usage = nil
    isStreaming = true
    activeGenerationID = generationID
    activeModelMessageCheckpoint = modelMessageCheckpoint

    streamingTask = Task {
      do {
        let client = try clientFactory()
        var completedToolRounds = 0
        var toolExecutionCache = [String: CachedToolExecution]()

        while true {
          let request = ChatRequest(
            context: context,
            messages: modelMessages,
            tools: toolRegistry.definitions,
          )
          var partialCalls = [Int: PartialToolCall]()
          var roundText = ""
          var roundReasoning = ""
          var emittedTextInRound = false

          for try await event in client.stream(request: request) {
            try Task.checkCancellation()
            switch event {
            case let .textDelta(delta):
              if !emittedTextInRound, completedToolRounds > 0, !delta.isEmpty {
                updateAssistant(id: assistantID) { message in
                  if !message.content.isEmpty { message.content += "\n\n" }
                }
              }
              emittedTextInRound = true
              roundText += delta
              updateAssistant(id: assistantID) { $0.content += delta }
            case let .reasoningDelta(delta):
              roundReasoning += delta
            case let .toolCallDelta(delta):
              var partial = partialCalls[delta.index] ?? PartialToolCall()
              if let id = delta.id { partial.id = id }
              if let name = delta.name { partial.name = name }
              if let argumentsDelta = delta.argumentsDelta {
                partial.arguments += argumentsDelta
              }
              partialCalls[delta.index] = partial
            case let .usage(usage):
              self.usage = usage
            }
          }

          try Task.checkCancellation()
          let calls = try finalizedCalls(from: partialCalls)
          guard !calls.isEmpty else {
            modelMessages.append(.assistant(
              content: roundText,
              reasoningContent: roundReasoning.isEmpty ? nil : roundReasoning,
            ))
            updateAssistant(id: assistantID) { $0.deliveryState = .complete }
            break
          }
          guard calls.count <= 4 else {
            throw ChatClientError.invalidResponse
          }
          guard completedToolRounds < 6 else {
            throw ChatClientError.toolRoundLimitExceeded
          }

          modelMessages.append(.assistant(
            content: roundText.isEmpty ? nil : roundText,
            reasoningContent: roundReasoning.isEmpty ? nil : roundReasoning,
            toolCalls: calls,
          ))
          for call in calls {
            try Task.checkCancellation()
            let executionKey = toolExecutionKey(for: call)
            if let cachedExecution = toolExecutionCache[executionKey] {
              updateToolActivity(id: cachedExecution.activityID) { $0.reuseCount += 1 }
              modelMessages.append(.tool(callID: call.id, content: cachedExecution.result.output))
              continue
            }
            let activityID = UUID()
            toolActivities.append(ChatToolActivity(
              id: activityID,
              assistantMessageID: assistantID,
              callID: call.id,
              toolName: call.name,
              displayName: toolRegistry.displayName(for: call.name),
              arguments: call.arguments,
              startedAt: Date(),
              state: .running,
            ))
            let result = await toolRegistry.execute(call)
            try Task.checkCancellation()
            updateToolActivity(id: activityID) { activity in
              activity.output = result.output
              activity.completedAt = Date()
              activity.state = result.succeeded ? .succeeded : .failed
            }
            toolExecutionCache[executionKey] = CachedToolExecution(
              activityID: activityID,
              result: result,
            )
            modelMessages.append(.tool(callID: call.id, content: result.output))
          }
          completedToolRounds += 1
        }
      } catch is CancellationError {
        if activeGenerationID == generationID {
          rollbackModelMessages(to: modelMessageCheckpoint)
          updateAssistant(id: assistantID) { $0.deliveryState = .cancelled }
        }
      } catch {
        if activeGenerationID == generationID {
          rollbackModelMessages(to: modelMessageCheckpoint)
          updateAssistant(id: assistantID) { $0.deliveryState = .failed }
          errorMessage = error.localizedDescription
        }
      }

      if activeGenerationID == generationID {
        activeGenerationID = nil
        activeModelMessageCheckpoint = nil
        isStreaming = false
        streamingTask = nil
      }
    }
  }

  private func finalizedCalls(from partialCalls: [Int: PartialToolCall]) throws -> [ChatToolCall] {
    try partialCalls.keys.sorted().map { index in
      guard let partial = partialCalls[index],
            let id = partial.id?.trimmingCharacters(in: .whitespacesAndNewlines),
            !id.isEmpty,
            let name = partial.name?.trimmingCharacters(in: .whitespacesAndNewlines),
            !name.isEmpty
      else {
        throw ChatClientError.invalidResponse
      }
      return ChatToolCall(
        id: id,
        name: name,
        arguments: partial.arguments.isEmpty ? "{}" : partial.arguments,
      )
    }
  }

  private func rollbackModelMessages(to checkpoint: Int) {
    guard modelMessages.count > checkpoint else { return }
    modelMessages.removeSubrange(checkpoint...)
  }

  private func toolExecutionKey(for call: ChatToolCall) -> String {
    let normalizedArguments: String
    if let data = call.arguments.data(using: .utf8),
       let object = try? JSONSerialization.jsonObject(with: data),
       let canonicalData = try? JSONSerialization.data(
         withJSONObject: object,
         options: [.sortedKeys, .withoutEscapingSlashes],
       )
    {
      normalizedArguments = String(decoding: canonicalData, as: UTF8.self)
    } else {
      normalizedArguments = call.arguments.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return "\(call.name)\n\(normalizedArguments)"
  }

  private func updateAssistant(id: UUID, update: (inout ChatMessage) -> Void) {
    guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
    update(&messages[index])
  }

  private func updateToolActivity(id: UUID, update: (inout ChatToolActivity) -> Void) {
    guard let index = toolActivities.firstIndex(where: { $0.id == id }) else { return }
    update(&toolActivities[index])
  }

  private func cancelRunningToolActivities() {
    for index in toolActivities.indices where toolActivities[index].state == .running {
      toolActivities[index].completedAt = Date()
      toolActivities[index].state = .cancelled
    }
  }
}

private struct PartialToolCall {
  var id: String?
  var name: String?
  var arguments = ""
}

private struct CachedToolExecution {
  let activityID: UUID
  let result: ChatToolExecutionResult
}
