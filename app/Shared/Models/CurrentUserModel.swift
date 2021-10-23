//
//  CurrentUserModel.swift
//  MNGA
//
//  Created by Bugen Zhao on 2021/10/23.
//

import Foundation
import SwiftUI
import Combine

class CurrentUserModel: ObservableObject {
  private let authStorage = AuthStorage.shared

  @Published var user: User? = nil

  private var cancellables = Set<AnyCancellable>()

  init() {
    authStorage
      .objectWillChange
      .sink { self.loadData(uid: self.authStorage.authInfo.uid) }
      .store(in: &cancellables)

    $user
      .compactMap { $0 }
      .removeDuplicates()
      .dropFirst()
      .sink { ToastModel.hud.message = .userSwitch($0.name) }
      .store(in: &cancellables)
  }

  func loadData(uid: String) {
    if uid.isEmpty { return }

    logicCallAsync(.remoteUser(.with { $0.userID = uid }), errorToastModel: nil) { (response: RemoteUserResponse) in
      self.user = response.user
      if self.authStorage.authInfo.uid == uid, response.user.id == uid, self.authStorage.authInfo.cachedName.isEmpty {
        var info = self.authStorage.authInfo
        info.cachedName = response.user.name
        self.authStorage.setCurrentAuth(info)
      }
    }
  }
}
