//
//  NotificationModel.swift
//  MNGA
//
//  Created by Bugen Zhao on 2021/10/17.
//

import Foundation
import Combine
import SwiftUI
import CombineExt

typealias NotificationDataSource = PagingDataSource<FetchNotificationResponse, Notification>

fileprivate extension NotificationDataSource {
  static func build() -> NotificationDataSource {
    NotificationDataSource.init(
      buildRequest: { _ in
        return .fetchNotification(.with { _ in })
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
    self.items.filter { $0.read == false }.count
  }

  var title: LocalizedStringKey {
    if unreadCount > 0 {
      return "Notifications (\(unreadCount))"
    } else {
      return "Notifications"
    }
  }
}

#if targetEnvironment(simulator)
  fileprivate let refreshInterval: TimeInterval = 5
#else
  fileprivate let refreshInterval: TimeInterval = 60
#endif

class NotificationModel: ObservableObject {
  @Published var dataSource: NotificationDataSource = .build()
  @Published var showing = false

  let timer = Timer.TimerPublisher(interval: refreshInterval, runLoop: .main, mode: .default).autoconnect()
  var cancellables = Set<AnyCancellable>()

  init() {
    dataSource.refresh()
    timer.sink { _ in self.dataSource.refresh() }.store(in: &cancellables)

    // buggy
    dataSource.objectWillChange.sink { [weak self] _ in
      if self?.showing == true { self?.objectWillChange.send() }
    } .store(in: &cancellables)

    dataSource.$refreshedTimes
      .map { _ in self.dataSource.items.filter { n in n.read == false }.count }
      .prepend(0)
      .pairwise()
      .map { $0.1 - $0.0 }
      .sink { new in if new > 0 { ToastModel.hud.message = .notification(new) } }
      .store(in: &cancellables)
  }
}
