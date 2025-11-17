//
//  TopicHistoryListView.swift
//  NGA
//
//  Created by Bugen Zhao on 7/5/21.
//

import Foundation
import SwiftUI

struct TopicHistoryListView: View {
  @StateObject var dataSource: PagingDataSource<TopicHistoryResponse, TopicSnapshot>
  @StateObject var search = BasicSearchModel()

  static func build() -> Self {
    let dataSource = PagingDataSource<TopicHistoryResponse, TopicSnapshot>(
      buildRequest: { _ in
        .topicHistory(TopicHistoryRequest.with {
          $0.limit = 1000
        })
      },
      onResponse: { response in
        let items = response.topics
        return (items, 1)
      },
      id: \.topicSnapshot.id
    )

    return Self(dataSource: dataSource)
  }

  func topicLink(@Binding snapshot: TopicSnapshot) -> some View {
    // Set the post date to the snapshot timestamp for display.
    var displayTopic = snapshot.topicSnapshot
    let snapshotDate = snapshot.timestamp / 1000 // snapshot timestamp is in milliseconds
    displayTopic.postDate = snapshotDate
    displayTopic.lastPostDate = snapshotDate

    return CrossStackNavigationLinkHack(destination: TopicDetailsView.build(topicBinding: $snapshot.topicSnapshot), id: displayTopic.id) {
      TopicRowView(topic: displayTopic, dimmedSubject: false)
    }
  }

  var body: some View {
    Group {
      if dataSource.notLoaded {
        ProgressView()
          .onAppear { dataSource.initialLoad() }
      } else {
        List {
          SafeForEach(
            $dataSource.items,
            id: \.topicSnapshot.id,
            where: { search.commitedText == nil || $0.topicSnapshot.subject.full.contains(search.commitedText!) }
          ) { snapshotBinding in
            topicLink($snapshot: snapshotBinding)
          }
        }
      }
    }
    .navigationTitle("History")
    .refreshable(dataSource: dataSource)
    .mayGroupedListStyle()
    .searchable(model: search, prompt: "Search History".localized)
  }
}
