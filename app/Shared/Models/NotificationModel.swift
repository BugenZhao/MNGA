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
    items.count(where: { !$0.read })
  }

  @Published var unreadCountAnimated = 0

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
      id: \.id,
    )

    // Refresh periodically.
    timer
      .prepend(.init())
      .sink { [weak self] _ in self?.refreshNotis() }
      .store(in: &notificationCancellables)

    // Not sure why `unreadCount` does not trigger animation.
    // Duplicate it to another `@Published` to make it work.
    $items
      .map { $0.count(where: { !$0.read }) }
      .debounce(for: .seconds(0), scheduler: RunLoop.main) // filter out intermediate changes
      .sink { [weak self] new in
        DispatchQueue.main.async { // can only trigger animation in next frame
          withAnimation { self?.unreadCountAnimated = new }
        }
      }
      .store(in: &notificationCancellables)
  }
}
