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

  @Published var unreadCountAnimated: Int = 0

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
        #if DEBUG
          let items = NotificationMock.merged(into: response.notis)
        #else
          let items = response.notis
        #endif
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

#if DEBUG
  /// Adds one notification of each type, to test without an account that has real ones.
  ///
  /// The logic module does not know about them, so their read state is kept here.
  enum NotificationMock {
    private static let idPrefix = "debug-mock-"
    private static let readIDsKey = "debugMockNotificationReadIDs"
    private static let baseTimestamp = UInt64(Date().timeIntervalSince1970)

    // Posts of a well-known test topic, so that the rows open real content. There is no well-known
    // short message, so its rows open the details page with an error.
    private static let tid = "45150945"
    private static let pid = "841045175"

    private static let specs: [(type: Notification.TypeEnum, title: String)] = [
      (.replyTopic, "Mock: reply to topic"),
      (.replyPost, "Mock: reply to post"),
      (.atTopic, "Mock: mention in topic"),
      (.atPost, "Mock: mention in post"),
      (.vote, "Mock: vote"),
      (.shortMessageStart, "Mock: new short message"),
      (.shortMessage, "Mock: short message"),
    ]

    private static var readIDs: Set<String> {
      get { Set(UserDefaults.standard.stringArray(forKey: readIDsKey) ?? []) }
      set { UserDefaults.standard.set(Array(newValue), forKey: readIDsKey) }
    }

    private static var items: [Notification] {
      let readIDs = readIDs
      return specs.enumerated().map { index, spec in
        Notification.with {
          $0.id = "\(idPrefix)\(spec.type.rawValue)"
          $0.type = spec.type
          $0.otherUser = .with { $0.name.normal = "MNGA Mock" }
          $0.otherPostID = .with {
            $0.tid = tid
            $0.pid = pid
          }
          $0.topicSubject = .with { $0.content = spec.title }
          $0.timestamp = baseTimestamp - UInt64(index) * 3600
          $0.page = 1
          $0.read = readIDs.contains($0.id)
        }
      }
    }

    static func merged(into notifications: [Notification]) -> [Notification] {
      guard PreferencesStorage.shared.debugMockNotifications else { return notifications }
      return (notifications + items).sorted { $0.timestamp > $1.timestamp }
    }

    static func mark(_ ids: [String], read: Bool) {
      let mockIDs = ids.filter { $0.hasPrefix(idPrefix) }
      if read {
        readIDs.formUnion(mockIDs)
      } else {
        readIDs.subtract(mockIDs)
      }
    }

    static func didToggle() {
      readIDs = []
      NotificationModel.shared.refresh()
    }
  }
#endif
