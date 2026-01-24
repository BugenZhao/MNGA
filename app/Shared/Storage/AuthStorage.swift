//
//  AuthStorage.swift
//  NGA
//
//  Created by Bugen Zhao on 7/1/21.
//

import Combine
import Foundation
import SwiftUI

class AuthStorage: ObservableObject {
  static let shared = AuthStorage()

  @Published var isSigning = false
  @Published var authResponse: AuthResponse? = nil

  // do not set this as value other than members in `allAuthInfos`
  @AppStorage("authInfo") var authInfoWrapper = WrappedMessage(inner: AuthInfo()) {
    didSet {
      syncAuthWithLogic()
    }
  }

  var authInfo: AuthInfo {
    get { authInfoWrapper.inner }
    set { authInfoWrapper.inner = newValue }
  }

  @AppStorage("allAuthInfos") var allAuthInfos = Set<AuthInfo>()

  init(defaultAuthInfo: AuthInfo? = nil) {
    if signedIn, allAuthInfos.isEmpty {
      allAuthInfos = [authInfo] // for backward compatibility
    }

    if let info = defaultAuthInfo { setCurrentAuth(info) }
    syncAuthWithLogic()
  }

  private func syncAuthWithLogic() {
    authResponse = try! logicCall(.auth(.with { $0.info = authInfo }))
  }

  var signedIn: Bool {
    !authInfo.token.isEmpty
  }

  func setCurrentAuth(_ authInfo: AuthInfo) {
    if let old = allAuthInfos.first(where: { $0.uid == authInfo.uid }) {
      allAuthInfos.remove(old)
    }
    allAuthInfos.insert(authInfo)
    self.authInfo = authInfo
    isSigning = false
  }

  func clearCurrentAuth() {
    if let old = allAuthInfos.first(where: { $0.uid == authInfo.uid }) {
      allAuthInfos.remove(old)
    }
    authInfo = allAuthInfos.first ?? AuthInfo()
  }
}
