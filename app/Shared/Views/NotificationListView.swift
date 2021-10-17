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
  typealias DataSource = PagingDataSource<FetchNotificationResponse, Notification>

  @StateObject var dataSource: DataSource

  static func build() -> Self {
    let dataSource = DataSource.init(
      buildRequest: { _ in
        return .fetchNotification(.with { _ in })
      },
      onResponse: { response in
        let items = response.notis
        return (items, 1)
      },
      id: \.hashIdentifiable.description
    )

    return Self(dataSource: dataSource)
  }

  @ViewBuilder
  func buildLink(for notification: Notification) -> some View {
    NavigationLink(destination: {
      TopicDetailsView.build(topic: notification.asTopic)
        .onAppear {
        let _: MarkNotificationReadResponse? = try? logicCall(.markNotiRead(.with { r in r.id = notification.id }))
      }
    }) {
      NotificationRowView(noti: notification)
    }
  }

  var body: some View {
    List {
      ForEach(dataSource.items, id: \.hashIdentifiable) { notification in
        buildLink(for: notification)
      }
    } .navigationTitle("Notifications")
      .onAppear { dataSource.initialLoad() }
      .mayGroupedListStyle()
      .refreshable(dataSource: dataSource)
  }
}

