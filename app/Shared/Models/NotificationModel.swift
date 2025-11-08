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

  // HACK: computed property won't trigger animation
  @Published var unreadCount = 0

  private func refreshNotis() {
    refresh(animated: true, silentOnError: true)
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

    // Play haptic when new notis arrive.
    $items
      .map { [weak self] items in
        let count = items.filter { $0.read == false }.count
        withAnimation { self?.unreadCount = count }
        return count
      }
      .prepend(0)
      .pairwise()
      .map { $0.1 - $0.0 }
      .sink { new in if new > 0 { HapticUtils.play(type: .warning) } }
      .store(in: &notificationCancellables)
  }
}
