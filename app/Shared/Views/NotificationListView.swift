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
  typealias DataSource = NotificationDataSource

  @ObservedObject var dataSource: DataSource

  @ViewBuilder
  func buildLink(for notification: Notification) -> some View {
    NavigationLink(destination: {
      Group {
        switch notification.type {
        case .shortMessage, .shortMessageStart:
          ShortMessageDetailsView.build(mid: notification.otherPostID.tid)
        default:
          TopicDetailsView.build(onlyPost: notification.otherPostID)
        }
      } .onAppear {
        let _: MarkNotificationReadResponse? = try? logicCall(.markNotiRead(.with { r in r.ids = [notification.id] }))
      }
    }) {
      NotificationRowView(noti: notification)
    }
  }

  @ViewBuilder
  var markAllAsReadButton: some View {
    Button(action: { markAllAsRead() }) {
      Label("Mark All as Read", systemImage: "checkmark.circle")
    } .disabled(dataSource.unreadCount == 0)
  }

  func markAllAsRead() {
    DispatchQueue.global(qos: .background).async {
      let request = SyncRequest.OneOf_Value.markNotiRead(.with { n in
        n.ids = dataSource.items.map { $0.id }
      })
      let _: MarkNotificationReadResponse? = try? logicCall(request)
      DispatchQueue.main.async {
        dataSource.refresh(animated: true)
      }
    }
  }

  var body: some View {
    List {
      ForEach(dataSource.items, id: \.id) { notification in
        buildLink(for: notification)
      }
    } .navigationTitle(dataSource.title)
      .onAppear { dataSource.initialLoad() }
      .mayGroupedListStyle()
      .refreshable(dataSource: dataSource)
      .toolbarWithFix { ToolbarItem(placement: .primaryAction) { markAllAsReadButton } }
  }
}

