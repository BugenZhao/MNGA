//
//  RecommendedTopicListView.swift
//  MNGA
//
//  Created by Bugen Zhao on 2021/10/4.
//

import Foundation
import SwiftUI

struct RecommendedTopicListView: View {
  typealias DataSource = PagingDataSource<TopicListResponse, Topic>

  let forum: Forum

  @StateObject var dataSource: DataSource

  static func build(forum: Forum) -> Self {
    let dataSource = DataSource(
      buildRequest: { page in
        .topicList(TopicListRequest.with {
          $0.id = forum.id
          $0.page = UInt32(page)
          $0.order = .postDate
          $0.recommendedOnly = true
        })
      },
      onResponse: { response in
        let items = response.topics
        let pages = response.pages
        return (items, Int(pages))
      },
      id: \.id,
    )

    return Self(forum: forum, dataSource: dataSource)
  }

  var body: some View {
    Group {
      if dataSource.notLoaded {
        ProgressView()
          .onAppear { dataSource.initialLoad() }
      } else {
        List {
          SafeForEach($dataSource.items, id: \.id) { topic in
            TopicRowLinkView(topic: topic, useTopicPostDate: true)
              .onAppear { dataSource.loadMoreIfNeeded(currentItem: topic.w) }
          }
        }
        .mayGroupedListStyle()
      }
    }.navigationTitle("Recommended Topics")
      .maybeNavigationSubtitle(forum.name)
      .refreshable(dataSource: dataSource)
  }
}
