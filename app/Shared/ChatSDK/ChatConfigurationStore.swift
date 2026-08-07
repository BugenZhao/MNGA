//
//  ChatConfigurationStore.swift
//  MNGA
//

import Combine
import CryptoKit
import Foundation

final class ChatConfigurationStore: ObservableObject {
  static let shared = ChatConfigurationStore()

  private enum Key {
    static let baseURL = "chatAPIBaseURL"
    static let model = "chatAPIModel"
    static let verifiedConfigurationFingerprint = "chatAPIVerifiedConfigurationFingerprint"
  }

  @Published private(set) var baseURL: String
  @Published private(set) var model: String
  @Published private(set) var apiKey: String
  @Published private(set) var verifiedConfigurationFingerprint: String?

  private let defaults: UserDefaults
  private let credentialStore: KeychainCredentialStore

  init(
    defaults: UserDefaults = .standard,
    credentialStore: KeychainCredentialStore = .init(),
  ) {
    self.defaults = defaults
    self.credentialStore = credentialStore
    baseURL = defaults.string(forKey: Key.baseURL) ?? ChatAPIConfiguration.defaultBaseURL
    model = defaults.string(forKey: Key.model) ?? ChatAPIConfiguration.defaultModel
    apiKey = (try? credentialStore.load()) ?? ""
    verifiedConfigurationFingerprint = defaults.string(forKey: Key.verifiedConfigurationFingerprint)
  }

  var isConfigured: Bool {
    !apiKey.isEmpty && !model.isEmpty && (try? ChatAPIConfiguration.validate(baseURL: baseURL)) != nil
  }

  var isAIEnabled: Bool {
    guard let configuration = try? configuration() else { return false }
    return isConnectionVerified(for: configuration)
  }

  func save(baseURL: String, apiKey: String, model: String) throws {
    let normalizedBaseURL = try ChatAPIConfiguration.validate(baseURL: baseURL).absoluteString
    let normalizedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalizedModel.isEmpty else { throw ChatClientError.missingModel }

    try credentialStore.save(apiKey)
    defaults.set(normalizedBaseURL, forKey: Key.baseURL)
    defaults.set(normalizedModel, forKey: Key.model)

    self.baseURL = normalizedBaseURL
    self.model = normalizedModel
    self.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  func configuration() throws -> ChatAPIConfiguration {
    try ChatAPIConfiguration(baseURL: baseURL, apiKey: apiKey, model: model)
  }

  func isConnectionVerified(for configuration: ChatAPIConfiguration) -> Bool {
    verifiedConfigurationFingerprint == Self.verificationFingerprint(for: configuration)
  }

  func recordSuccessfulConnectionTest(for configuration: ChatAPIConfiguration) {
    let fingerprint = Self.verificationFingerprint(for: configuration)
    defaults.set(fingerprint, forKey: Key.verifiedConfigurationFingerprint)
    verifiedConfigurationFingerprint = fingerprint
  }

  func recordFailedConnectionTest(for configuration: ChatAPIConfiguration) {
    guard isConnectionVerified(for: configuration) else { return }
    defaults.removeObject(forKey: Key.verifiedConfigurationFingerprint)
    verifiedConfigurationFingerprint = nil
  }

  private static func verificationFingerprint(for configuration: ChatAPIConfiguration) -> String {
    let value = [
      configuration.baseURL.absoluteString,
      configuration.model,
      configuration.apiKey,
    ].joined(separator: "\u{1F}")
    return SHA256.hash(data: Data(value.utf8))
      .map { String(format: "%02x", $0) }
      .joined()
  }
}
