//
//  AISettingsView.swift
//  MNGA
//

import SwiftUI
import UIKit

struct AISettingsView: View {
  @Environment(\.dismiss) private var dismiss
  @ObservedObject private var store: ChatConfigurationStore

  @State private var baseURL: String
  @State private var apiKey: String
  @State private var model: String
  @State private var errorMessage: String?
  @State private var connectionStatus = ConnectionTestStatus.idle
  @State private var connectionLogs = [ConnectionTestLogEntry]()
  @State private var connectionTestTask: Task<Void, Never>?

  init(store: ChatConfigurationStore = .shared) {
    _store = ObservedObject(wrappedValue: store)
    _baseURL = State(initialValue: store.baseURL)
    _apiKey = State(initialValue: store.apiKey)
    _model = State(initialValue: store.model)
  }

  private func save() {
    do {
      try store.save(baseURL: baseURL, apiKey: apiKey, model: model)
      dismiss()
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func testConnection() {
    connectionTestTask?.cancel()
    connectionLogs.removeAll()
    connectionStatus = .testing
    appendConnectionLog("Validating configuration...".localized)

    let configuration: ChatAPIConfiguration
    do {
      configuration = try ChatAPIConfiguration(baseURL: baseURL, apiKey: apiKey, model: model)
    } catch {
      connectionStatus = .failed
      appendConnectionLog(String(format: "Connection failed: %@".localized, error.localizedDescription))
      return
    }

    appendConnectionLog(String(
      format: "POST %@".localized,
      configuration.chatCompletionsURL.absoluteString,
    ))
    appendConnectionLog(String(format: "Testing model: %@".localized, configuration.model))
    let startedAt = Date()

    connectionTestTask = Task { @MainActor in
      do {
        let report = try await ChatConnectionTester().test(configuration: configuration)
        try Task.checkCancellation()
        let duration = Date().timeIntervalSince(startedAt)
        appendConnectionLog(String(
          format: "HTTP %lld in %.2f s".localized,
          report.statusCode,
          duration,
        ))
        appendConnectionLog(String(format: "Response model: %@".localized, report.model))
        if let inputTokens = report.inputTokens, let outputTokens = report.outputTokens {
          appendConnectionLog(String(
            format: "Tokens: %lld input, %lld output".localized,
            inputTokens,
            outputTokens,
          ))
        }
        appendConnectionLog(String(format: "Response: %@".localized, report.responsePreview))
        appendConnectionLog("Connection succeeded.".localized)
        connectionStatus = .succeeded
      } catch is CancellationError {
        appendConnectionLog("Connection test cancelled.".localized)
        connectionStatus = .idle
      } catch {
        let duration = Date().timeIntervalSince(startedAt)
        if case let ChatClientError.httpStatus(code, _, _) = error {
          appendConnectionLog(String(
            format: "HTTP %lld in %.2f s".localized,
            code,
            duration,
          ))
        } else {
          appendConnectionLog(String(
            format: "Request failed after %.2f s".localized,
            duration,
          ))
        }
        appendConnectionLog(String(format: "Connection failed: %@".localized, error.localizedDescription))
        connectionStatus = .failed
      }
      connectionTestTask = nil
    }
  }

  private func appendConnectionLog(_ message: String) {
    connectionLogs.append(.init(message: message))
    if connectionLogs.count > 80 {
      connectionLogs.removeFirst(connectionLogs.count - 80)
    }
  }

  private var connectionLogText: String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "HH:mm:ss"
    return connectionLogs.map { entry in
      "[\(formatter.string(from: entry.createdAt))] \(entry.message)"
    }.joined(separator: "\n")
  }

  var body: some View {
    Form {
      Section {
        TextField("Base API URL", text: $baseURL)
          .keyboardType(.URL)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled(true)
        SecureField("API Key", text: $apiKey)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled(true)
        TextField("Model", text: $model)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled(true)
      } header: {
        Text("OpenAI-Compatible API")
      } footer: {
        Text("Enter a Base API URL ending in /v1, or the full /chat/completions endpoint. The API key is stored in Keychain.")
      }

      Section {
        Label("Stable topic context is cached separately from changing chat messages.", systemImage: "bolt.horizontal.circle")
      } header: {
        Text("Prompt Caching")
      } footer: {
        Text("The provider must support OpenAI prompt caching. Unsupported cache extensions are detected and disabled automatically.")
      }

      Section {
        Button(action: testConnection) {
          HStack {
            Label("Test Connection", systemImage: "network")
            Spacer()
            if connectionStatus == .testing {
              ProgressView()
            }
          }
        }
        .disabled(connectionStatus == .testing)

        if connectionStatus != .idle {
          Label(connectionStatus.title, systemImage: connectionStatus.icon)
            .foregroundStyle(connectionStatus.color)
        }

        if !connectionLogs.isEmpty {
          ScrollView {
            LazyVStack(alignment: .leading, spacing: 5) {
              ForEach(connectionLogs) { entry in
                Text("[\(entry.createdAt.formatted(.dateTime.hour().minute().second()))] \(entry.message)")
                  .frame(maxWidth: .infinity, alignment: .leading)
              }
            }
          }
          .frame(maxHeight: 220)
          .font(.caption.monospaced())
          .textSelection(.enabled)

          HStack {
            Button("Copy Log", systemImage: "doc.on.doc") {
              UIPasteboard.general.string = connectionLogText
            }
            Spacer()
            Button("Clear Log", systemImage: "trash", role: .destructive) {
              connectionLogs.removeAll()
              connectionStatus = .idle
            }
            .disabled(connectionStatus == .testing)
          }
        }
      } header: {
        Text("Connection Test")
      } footer: {
        Text("Sends a small request using the unsaved values above. The API key is never included in the log.")
      }
    }
    .navigationTitle("AI Chat Settings")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        Button("Save", action: save)
          .disabled(connectionStatus == .testing)
      }
    }
    .alert("Error", isPresented: Binding(
      get: { errorMessage != nil },
      set: { if !$0 { errorMessage = nil } },
    )) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(errorMessage ?? "")
    }
    .onDisappear { connectionTestTask?.cancel() }
  }
}

private enum ConnectionTestStatus {
  case idle
  case testing
  case succeeded
  case failed

  var title: String {
    switch self {
    case .idle: ""
    case .testing: "Testing...".localized
    case .succeeded: "Connection Succeeded".localized
    case .failed: "Connection Failed".localized
    }
  }

  var icon: String {
    switch self {
    case .idle: "circle"
    case .testing: "clock"
    case .succeeded: "checkmark.circle.fill"
    case .failed: "xmark.circle.fill"
    }
  }

  var color: Color {
    switch self {
    case .idle, .testing: .secondary
    case .succeeded: .green
    case .failed: .red
    }
  }
}

private struct ConnectionTestLogEntry: Identifiable {
  let id = UUID()
  let createdAt = Date()
  let message: String
}
