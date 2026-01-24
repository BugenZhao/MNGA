//
//  CurrentUserModel.swift
//  MNGA
//
//  Created by Bugen Zhao on 2021/10/23.
//

import Combine
import Foundation
import SwiftUI

class CurrentUserModel: ObservableObject {
  private let authStorage = AuthStorage.shared

  @Published var user: User? = nil

  private var cancellables = Set<AnyCancellable>()

  private let clockInTimer = Timer.publish(every: 2 * 60, on: .main, in: .common).autoconnect()

  init() {
    authStorage
      .objectWillChange
      .map { _ in self.authStorage.authInfo.uid }
      .removeDuplicates()
      .sink { self.loadData(uid: $0) }
      .store(in: &cancellables)

    authStorage.$authResponse
      .delay(for: .seconds(5), scheduler: RunLoop.main)
      .sink { _ in self.clockIn() }
      .store(in: &cancellables)

    clockInTimer
      .dropFirst()
      .sink { _ in self.clockIn() }
      .store(in: &cancellables)

    $user
      .compactMap(\.self)
      .removeDuplicates { $0.id == $1.id }
      .dropFirst()
      .filter { $0.id != "" }
      .sink { ToastModel.showAuto(.userSwitch($0.name.display)) }
      .store(in: &cancellables)
  }

  func loadData(uid: String) {
    if uid.isEmpty {
      // Sign out or initial load.
      user = nil
      return
    }
    if uid == user?.id {
      // Already loaded.
      return
    }

    logicCallAsync(.remoteUser(.with { $0.userID = uid }), errorToastModel: nil) { (response: RemoteUserResponse) in
      self.user = response.user
      if self.authStorage.authInfo.uid == uid, response.user.id == uid, self.authStorage.authInfo.cachedName.isEmpty {
        var info = self.authStorage.authInfo
        info.cachedName = response.user.name.normal
        self.authStorage.setCurrentAuth(info)
      }
    }
  }

  func clockIn() {
    let uid = authStorage.authInfo.uid
    if uid.isEmpty { return }

    logicCallAsync(.clockIn(.init()), errorToastModel: nil) { (response: ClockInResponse) in
      if response.isFirstTime {
        ToastModel.showAuto(.clockIn("\(self.user?.name.display ?? "???") @ \(response.date)"))
      }
    }
  }
}
