//
//  AuthStorage.swift
//  NGA
//
//  Created by Bugen Zhao on 7/1/21.
//

import Foundation
import SwiftUI

class AuthStorage: ObservableObject {
  static let shared = AuthStorage()

  @Published var isSigning = false

  @AppStorage("authInfo") var authInfo = WrappedMessage(inner: AuthInfo()) {
    didSet {
      reAuth()
    }
  }

  init() {
    reAuth()
  }

  init(defaultAuthInfo: AuthInfo) {
    setAuth(defaultAuthInfo)
  }

  private func reAuth() {
    let _: AuthResponse = try! logicCall(.auth(.with { $0.info = authInfo.inner }))
  }

  var signedIn: Bool {
    !authInfo.inner.token.isEmpty
  }

  func setAuth(_ authInfo: AuthInfo) {
    self.authInfo.inner = authInfo
    isSigning = false
  }

  func clearAuth() {
    self.authInfo.inner = AuthInfo()
  }
}
