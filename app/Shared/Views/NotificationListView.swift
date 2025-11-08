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
        binding.w.read = true // frontend
        let _: MarkNotificationReadResponse? = try? logicCall(.markNotiRead(.with { r in r.ids = [notification.id] })) // backend
      }
    }) {
      NotificationRowView(noti: notification)
    }
  }

  @ViewBuilder
  var markAllAsReadButton: some View {
    Button(action: { markAllAsRead() }) {
      Label("Mark All as Read", systemImage: "checkmark")
    }.disabled(notis.unreadCount == 0)
  }

  func markAllAsRead() {
    DispatchQueue.global(qos: .background).async {
      let request = SyncRequest.OneOf_Value.markNotiRead(.with { n in
        n.ids = notis.items.map(\.id)
      })
      let _: MarkNotificationReadResponse? = try? logicCall(request)
      DispatchQueue.main.async {
        notis.refresh(animated: true)
      }
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
    .navigationSubtitle(notis.unreadCount > 0 ? "\(notis.unreadCount) Unread" : "All Read")
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
  @Environment(\.inNotificationSheet) var inNotificationSheet

  func showAction() {
    switch show {
    case .sheet:
      notis.showingSheet = true
    case .fromUserMenu:
      notis.showingFromUserMenu = true
    }
  }

  var body: some ToolbarContent {
    // Only show if not from notification list view.
    if notis.unreadCount > 0,
       show == .fromUserMenu || !notis.showingFromUserMenu,
       !inNotificationSheet
    {
      // ToolbarSpacer(.fixed, placement: placement)
      ToolbarItem(placement: placement) {
        Button(action: showAction) {
          Label("Notifications", systemImage: "bell.fill")
            .badge(notis.unreadCount)
        }
        .animation(.default, value: notis.unreadCount)
      }
      // ToolbarSpacer(.fixed, placement: placement)
    }
  }
}
