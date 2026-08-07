//
//  ChatConfigurationStore.swift
//  MNGA
//

import Combine
import Foundation

final class ChatConfigurationStore: ObservableObject {
  static let shared = ChatConfigurationStore()

  private enum Key {
    static let baseURL = "chatAPIBaseURL"
    static let model = "chatAPIModel"
  }

  @Published private(set) var baseURL: String
  @Published private(set) var model: String
  @Published private(set) var apiKey: String

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
  }

  var isConfigured: Bool {
    !apiKey.isEmpty && !model.isEmpty && (try? ChatAPIConfiguration.validate(baseURL: baseURL)) != nil
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
}
