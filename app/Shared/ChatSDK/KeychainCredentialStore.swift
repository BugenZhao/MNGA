//
//  KeychainCredentialStore.swift
//  MNGA
//

import Foundation
import Security

struct KeychainCredentialStore {
  private let service = "com.bugenzhao.MNGA.chat-api"
  private let account = "api-key"

  func load() throws -> String {
    var query = baseQuery
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound { return "" }
    guard status == errSecSuccess else { throw error(for: status) }
    guard let data = result as? Data, let value = String(data: data, encoding: .utf8) else {
      throw ChatClientError.invalidResponse
    }
    return value
  }

  func save(_ value: String) throws {
    let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if value.isEmpty {
      let status = SecItemDelete(baseQuery as CFDictionary)
      guard status == errSecSuccess || status == errSecItemNotFound else {
        throw error(for: status)
      }
      return
    }

    let data = Data(value.utf8)
    let attributes = [kSecValueData as String: data]
    let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
    if updateStatus == errSecSuccess { return }
    guard updateStatus == errSecItemNotFound else { throw error(for: updateStatus) }

    var query = baseQuery
    query[kSecValueData as String] = data
    query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    let addStatus = SecItemAdd(query as CFDictionary, nil)
    guard addStatus == errSecSuccess else { throw error(for: addStatus) }
  }

  private var baseQuery: [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecUseDataProtectionKeychain as String: true,
    ]
  }

  private func error(for status: OSStatus) -> NSError {
    let message = SecCopyErrorMessageString(status, nil) as String? ?? "Keychain error"
    return NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: [NSLocalizedDescriptionKey: message])
  }
}
