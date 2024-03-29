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

  var title: LocalizedStringKey {
    if unreadCount > 0 {
      "Notifications (\(unreadCount))"
    } else {
      "Notifications"
    }
  }
}

#if targetEnvironment(simulator)
  fileprivate let refreshInterval: TimeInterval = 10
#else
  fileprivate let refreshInterval: TimeInterval = 60
#endif

class NotificationModel: ObservableObject {
  static let shared = NotificationModel()

  @Published var dataSource: NotificationDataSource = .build()
  @Published var showing = false
  @Published var showingSheet = false

  let timer = Timer.TimerPublisher(interval: refreshInterval, runLoop: .main, mode: .default).autoconnect()
  var cancellables = Set<AnyCancellable>()

  private func refreshNotis() {
    dataSource.refresh(silentOnError: true)
  }

  init() {
    timer
      .prepend(.init())
      .sink { _ in self.refreshNotis() }
      .store(in: &cancellables)

    // may buggy
    dataSource.objectWillChange
      .sink { [weak self] _ in
        if self?.showing == true { self?.objectWillChange.send() }
      }.store(in: &cancellables)

    dataSource.$lastRefreshTime
      .map { _ in self.dataSource.items.filter { n in n.read == false }.count }
      .prepend(0)
      .pairwise()
      .map { $0.1 - $0.0 }
      .sink { new in if new > 0 { ToastModel.showAuto(.notification(new)) } }
      .store(in: &cancellables)
  }
}
