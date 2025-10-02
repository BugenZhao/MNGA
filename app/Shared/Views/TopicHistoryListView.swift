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

  var body: some View {
    Group {
      if dataSource.notLoaded {
        ProgressView()
          .onAppear { dataSource.initialLoad() }
      } else {
        List {
          let items = dataSource.items.filter { search.commitedText == nil || $0.topicSnapshot.subject.full.contains(search.commitedText!) }
          ForEachOrEmpty(items, id: \.topicSnapshot.id) { snapshot in
            // Set the post date to the snapshot timestamp for display.
            var topic = snapshot.topicSnapshot
            let snapshotDate = snapshot.timestamp / 1000 // snapshot timestamp is in milliseconds
            topic.postDate = snapshotDate
            topic.lastPostDate = snapshotDate

            return CrossStackNavigationLinkHack(destination: TopicDetailsView.build(topic: topic), id: topic.id) {
              TopicRowView(topic: topic, dimmedSubject: false)
            }
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
