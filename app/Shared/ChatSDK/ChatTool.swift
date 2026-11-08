//
//  ChatTool.swift
//  MNGA
//

import Foundation

struct ChatToolDefinition {
  let name: String
  let displayName: String
  let description: String
  let parameters: [String: Any]
}

protocol ChatTool {
  var definition: ChatToolDefinition { get }
  func execute(arguments: Data) async throws -> String
}

struct ChatToolExecutionResult {
  let output: String
  let succeeded: Bool
}

final class ChatToolRegistry {
  static let empty = ChatToolRegistry(tools: [])

  private static let maximumArgumentBytes = 64 * 1024
  private static let maximumOutputCharacters = 48_000

  private let toolsByName: [String: any ChatTool]

  init(tools: [any ChatTool]) {
    toolsByName = tools.reduce(into: [:]) { result, tool in
      guard result[tool.definition.name] == nil else {
        assertionFailure("Duplicate chat tool: \(tool.definition.name)")
        return
      }
      result[tool.definition.name] = tool
    }
  }

  var definitions: [ChatToolDefinition] {
    toolsByName.values.map(\.definition).sorted { $0.name < $1.name }
  }

  func displayName(for toolName: String) -> String {
    toolsByName[toolName]?.definition.displayName ?? toolName
  }

  func execute(_ call: ChatToolCall) async -> ChatToolExecutionResult {
    guard let tool = toolsByName[call.name] else {
      return failedResult("Unknown tool: \(call.name)")
    }

    let arguments = Data(call.arguments.utf8)
    guard arguments.count <= Self.maximumArgumentBytes else {
      return failedResult("Tool arguments exceed the size limit.")
    }

    do {
      let output = try await tool.execute(arguments: arguments)
      if output.count > Self.maximumOutputCharacters {
        let object: [String: Any] = [
          "ok": true,
          "truncated": true,
          "content": String(output.prefix(Self.maximumOutputCharacters)),
        ]
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        return ChatToolExecutionResult(
          output: String(decoding: data, as: UTF8.self),
          succeeded: true,
        )
      }
      return ChatToolExecutionResult(output: output, succeeded: outputSucceeded(output))
    } catch {
      return failedResult(toolErrorDescription(error))
    }
  }

  private func failedResult(_ message: String) -> ChatToolExecutionResult {
    let object: [String: Any] = ["ok": false, "error": message]
    let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    return ChatToolExecutionResult(
      output: String(decoding: data ?? Data("{\"ok\":false}".utf8), as: UTF8.self),
      succeeded: false,
    )
  }

  private func outputSucceeded(_ output: String) -> Bool {
    guard let data = output.data(using: .utf8),
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let succeeded = object["ok"] as? Bool
    else {
      return true
    }
    return succeeded
  }

  private func toolErrorDescription(_ error: Error) -> String {
    guard let decodingError = error as? DecodingError else {
      return error.localizedDescription
    }

    let path: String
    let description: String
    switch decodingError {
    case let .typeMismatch(_, context), let .valueNotFound(_, context):
      path = context.codingPath.map(\.stringValue).joined(separator: ".")
      description = context.debugDescription
    case let .keyNotFound(key, context):
      path = (context.codingPath + [key]).map(\.stringValue).joined(separator: ".")
      description = context.debugDescription
    case let .dataCorrupted(context):
      path = context.codingPath.map(\.stringValue).joined(separator: ".")
      description = context.debugDescription
    @unknown default:
      return error.localizedDescription
    }

    let location = path.isEmpty ? "arguments" : path
    return "Invalid tool arguments at \(location): \(description)"
  }
}
