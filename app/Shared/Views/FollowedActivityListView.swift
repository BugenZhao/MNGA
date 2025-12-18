//
//  FollowedActivityListView.swift
//  MNGA
//
//  Created by Bugen Zhao on 2025/12/18.
//

import Foundation
import SwiftUI
import SwiftUIX

struct FollowedActivityListView: View {
  typealias DataSource = PagingDataSource<ActivityListResponse, Activity>

  @StateObject var dataSource: DataSource

  static func build() -> Self {
    let dataSource = DataSource(
      buildRequest: { page in
        .activityList(.with { $0.page = UInt32(page) })
      },
      onResponse: { response in
        (response.activities, Int(response.pages))
      },
      id: \.id
    )

    return Self(dataSource: dataSource)
  }

  @ViewBuilder
  func destination(for activity: Activity) -> some View {
    if activity.postID.pid == "0" || activity.postID.pid.isEmpty {
      TopicDetailsView.build(topic: activity.topic)
    } else {
      TopicDetailsView.build(topic: activity.topic, onlyPost: (id: activity.postID, atPage: nil))
    }
  }

  var body: some View {
    Group {
      if dataSource.notLoaded {
        ProgressView()
          .onAppear { dataSource.initialLoad() }
      } else if dataSource.items.isEmpty {
        ContentUnavailableView("Empty", systemImage: "tray")
      } else {
        List {
          ForEach(dataSource.items, id: \.id) { activity in
            CrossStackNavigationLinkHack(id: activity.id, destination: {
              destination(for: activity)
            }) {
              FollowedActivityRowView(activity: activity)
            }.onAppear { dataSource.loadMoreIfNeeded(currentItem: activity) }
          }
        }
      }
    }
    .navigationTitle("Followed Activity")
    .mayGroupedListStyle()
    .refreshable(dataSource: dataSource)
  }
}
