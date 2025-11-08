//
//  NotificationModel.swift
//  MNGA
//
//  Created by Bugen Zhao on 2021/10/17.
//

import Combine
import CombineExt
import Foundation
import SwiftUI

typealias NotificationDataSource = PagingDataSource<FetchNotificationResponse, Notification>

private extension NotificationDataSource {
  static func build() -> NotificationDataSource {
    NotificationDataSource(
      buildRequest: { _ in
        .fetchNotification(.with { _ in })
      },
      onResponse: { response in
        let items = response.notis
        return (items, 1)
      },
      id: \.id
    )
  }
}

extension NotificationDataSource {
  var unreadCount: Int {
    items.filter { $0.read == false }.count
  }

  var titleWithUnread: LocalizedStringKey {
    if unreadCount > 0 {
      "Notifications (\(unreadCount))"
    } else {
      "Notifications"
    }
  }
}

class NotificationModel: ObservableObject {
  static let shared = NotificationModel()

  static var refreshInterval: TimeInterval {
    #if DEBUG
      10
    #else
      60
    #endif
  }

  @Published var dataSource: NotificationDataSource = .build()
  @Published var showingFromUserMenu = false
  @Published var showingSheet = false

  let timer = Timer.TimerPublisher(interval: refreshInterval, runLoop: .main, mode: .default).autoconnect()
  var cancellables = Set<AnyCancellable>()

  private func refreshNotis() {
    dataSource.refresh(animated: true, silentOnError: true)
  }

  var unreadCount: Int {
    dataSource.unreadCount
  }

  init() {
    // Refresh periodically.
    timer
      .prepend(.init())
      .sink { _ in self.refreshNotis() }
      .store(in: &cancellables)

    // Play haptic when new notis arrive.
    dataSource.$lastRefreshTime
      .map { _ in self.dataSource.items.filter { n in n.read == false }.count }
      .prepend(0)
      .pairwise()
      .map { $0.1 - $0.0 }
      .sink { new in if new > 0 {
        // ToastModel.showAuto(.notification(new))
        HapticUtils.play(type: .warning)
      } }
      .store(in: &cancellables)

    // Forward nested observable.
    dataSource.objectWillChange
      .sink { self.objectWillChange.send() }
      .store(in: &cancellables)
  }
}
