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
  @StateObject var dataSource = NotificationModel.shared.dataSource

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
    }.disabled(dataSource.unreadCount == 0)
  }

  func markAllAsRead() {
    DispatchQueue.global(qos: .background).async {
      let request = SyncRequest.OneOf_Value.markNotiRead(.with { n in
        n.ids = dataSource.items.map(\.id)
      })
      let _: MarkNotificationReadResponse? = try? logicCall(request)
      DispatchQueue.main.async {
        dataSource.refresh(animated: true)
      }
    }
  }

  var body: some View {
    Group {
      if dataSource.notLoaded {
        ProgressView()
          .onAppear { dataSource.initialLoad() }
      } else {
        List {
          ForEach($dataSource.items, id: \.id) { notification in
            buildLink(for: notification)
          }
        }
      }
    }
    .navigationTitle("Notifications")
    .if(dataSource.unreadCount > 0) { $0.navigationSubtitle("\(dataSource.unreadCount) unread") }
    .mayGroupedListStyle()
    .refreshable(dataSource: dataSource)
    .toolbar { ToolbarItem(placement: .primaryAction) { markAllAsReadButton } }
  }
}

struct NotificationListNavigationView: View {
  var body: some View {
    NavigationStack {
      NotificationListView()
    }
    .modifier(MainToastModifier.bannerOnly())
    .modifier(GlobalSheetsModifier())
  }
}

struct NotificationToolbarItem: ToolbarContent {
  let placement: ToolbarItemPlacement

  @StateObject var notis = NotificationModel.shared

  var body: some ToolbarContent {
    if notis.unreadCount > 0 {
      ToolbarItem(placement: placement) {
        Button(action: { notis.showingSheet = true }) {
          Label("Notifications", systemImage: "bell")
            .badge(notis.unreadCount)
        }
      }
    }
  }
}
