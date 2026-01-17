//
//  NotificationListView.swift
//  NotificationListView
//
//  Created by Bugen Zhao on 7/17/21.
//

import Foundation
import SwiftUI
import SwiftUIX

struct NotificationListView: View {
  @StateObject var notis = NotificationModel.shared

  @ViewBuilder
  func buildLink(for binding: Binding<Notification>) -> some View {
    let notification = binding.w

    CrossStackNavigationLinkHack(id: notification.id, destination: {
      Group {
        switch notification.type {
        case .shortMessage, .shortMessageStart:
          ShortMessageDetailsView.build(mid: notification.otherPostID.tid)
        default:
          TopicDetailsView.build(onlyPost: (id: notification.otherPostID, atPage: max(Int(notification.page), 1)))
        }
      }.onAppear {
        mark([notification.id], read: true)
      }
    }) {
      NotificationRowView(noti: notification)
        .swipeActions(edge: .trailing) {
          Button(action: { mark([notification.id], read: !notification.read) }) {
            if notification.read {
              Label("Unread", systemImage: "envelope.badge")
            } else {
              Label("Read", systemImage: "envelope.open").tint(.accentColor)
            }
          }
        }
    }
  }

  @ViewBuilder
  var markAllAsReadButton: some View {
    Button(action: { markAllAsRead() }) {
      Label("Mark All as Read", systemImage: "checkmark")
    }.disabled(notis.unreadCount == 0)
  }

  func mark(_ ids: [String], read: Bool, onSuccess: @escaping () -> Void = {}) {
    DispatchQueue.global(qos: .background).async {
      let request = SyncRequest.OneOf_Value.markNotiRead(.with { n in
        n.ids = ids
        n.read = read
      })
      let _: MarkNotificationReadResponse? = try? logicCall(request)
      DispatchQueue.main.async {
        for id in ids {
          if let index = notis.items.firstIndex(where: { $0.id == id }) {
            notis.items[index].read = read // mark as read in frontend, without triggering real refresh
          }
        }
        onSuccess()
      }
    }
  }

  func markAllAsRead() {
    mark(notis.items.filter { !$0.read }.map(\.id), read: true) {
      HapticUtils.play(type: .success)
    }
  }

  var body: some View {
    Group {
      if notis.notLoaded {
        ProgressView()
          .onAppear { notis.initialLoad() }
      } else {
        List {
          ForEach($notis.items, id: \.id) { notification in
            buildLink(for: notification)
          }
        }
      }
    }
    .navigationTitle("Notifications")
    .maybeNavigationSubtitle(localized: notis.unreadCount > 0 ? "\(notis.unreadCount) Unread" : "All Read")
    .mayGroupedListStyle()
    .refreshable(dataSource: notis)
    .toolbar { ToolbarItem(placement: .primaryAction) { markAllAsReadButton } }
  }
}

struct InNotificationSheetKey: EnvironmentKey {
  static let defaultValue = false
}

extension EnvironmentValues {
  var inNotificationSheet: Bool {
    get { self[InNotificationSheetKey.self] }
    set { self[InNotificationSheetKey.self] = newValue }
  }
}

struct NotificationListNavigationView: View {
  @State var detents: Set<PresentationDetent> = [.medium, .large]
  @State var detent: PresentationDetent = .medium

  func enableMediumDetent() {
    detents = [.medium, .large]
  }

  func disableMediumDetent() {
    detent = .large
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      detents = [.large]
    }
  }

  var body: some View {
    NavigationStack {
      NotificationListView()
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { enableMediumDetent() }
        .onDisappear { disableMediumDetent() }
    }
    .environment(\.inNotificationSheet, true)
    .modifier(MainToastModifier.bannerOnly())
    .modifier(GlobalSheetsModifier())
    .presentationDetents(detents, selection: $detent)
  }
}

struct NotificationToolbarItem: ToolbarContent {
  enum Show {
    case sheet
    case fromUserMenu
  }

  let placement: ToolbarItemPlacement
  let show: Show

  init(placement: ToolbarItemPlacement, show: Show = .sheet) {
    self.placement = placement
    self.show = show
  }

  @StateObject var notis = NotificationModel.shared
  @StateObject var prefs = PreferencesStorage.shared

  @Environment(\.inNotificationSheet) var inNotificationSheet

  func showAction() {
    switch show {
    case .sheet:
      notis.showingSheet = true
    case .fromUserMenu:
      notis.showingFromUserMenu = true
    }
  }

  var unreadCount: Int {
    notis.unreadCountAnimated
  }

  @ViewBuilder
  var bodyView: some View {
    // Only show if not from notification list view.
    if unreadCount > 0 || prefs.debugAlwaysShowNotificationBadge,
       show == .fromUserMenu || !notis.showingFromUserMenu,
       !inNotificationSheet
    {
      Button(action: showAction) {
        Label("Notifications", systemImage: "bell.fill")
          .badge(unreadCount)
      }
    }
  }

  var body: some ToolbarContent {
    ToolbarItem(placement: placement) {
      bodyView
    }
  }
}
