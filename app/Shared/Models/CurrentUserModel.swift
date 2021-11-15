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

  private let clockInTimer = Timer.publish(every: 10 * 60, on: .main, in: .common).autoconnect()

  init() {
    authStorage
      .objectWillChange
      .sink { self.loadData(uid: self.authStorage.authInfo.uid) }
      .store(in: &cancellables)

    authStorage.$authResponse
      .map { $0?.shouldClockIn ?? false }
      .filter { $0 }
      .delay(for: .seconds(5), scheduler: RunLoop.main)
      .sink { _ in self.clockIn() }
      .store(in: &cancellables)

    clockInTimer
      .dropFirst()
      .sink { _ in self.clockIn() }
      .store(in: &cancellables)

    $user
      .compactMap { $0 }
      .removeDuplicates { $0.id == $1.id }
      .dropFirst()
      .filter { $0.id != "" }
      .sink { ToastModel.hud.message = .userSwitch($0.name.display) }
      .store(in: &cancellables)
  }

  func loadData(uid: String) {
    if uid.isEmpty { return }

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
    logicCallAsync(.clockIn(.init())) { (response: ClockInResponse) in
      if response.isFirstTime {
        ToastModel.hud.message = .clockIn(response.date)
      }
    }
  }
}
