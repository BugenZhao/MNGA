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

class NotificationModel: PagingDataSource<FetchNotificationResponse, Notification> {
  static let shared = NotificationModel()

  static var refreshInterval: TimeInterval {
    #if DEBUG
      10
    #else
      60
    #endif
  }

  @Published var showingFromUserMenu = false
  @Published var showingSheet = false

  private let timer = Timer.TimerPublisher(interval: refreshInterval, runLoop: .main, mode: .default).autoconnect()
  private var notificationCancellables = Set<AnyCancellable>()

  var unreadCount: Int {
    items.filter { !$0.read }.count
  }

  private func refreshNotis() {
    Task {
      let currentUnreadCount = unreadCount
      await refreshAsync(animated: true, silentOnError: true)
      if unreadCount > currentUnreadCount {
        HapticUtils.play(type: .warning)
      }
    }
  }

  init() {
    super.init(
      buildRequest: { _ in
        .fetchNotification(.with { _ in })
      },
      onResponse: { response in
        let items = response.notis
        return (items, 1)
      },
      id: \.id
    )

    // Refresh periodically.
    timer
      .prepend(.init())
      .sink { [weak self] _ in self?.refreshNotis() }
      .store(in: &notificationCancellables)
  }
}
