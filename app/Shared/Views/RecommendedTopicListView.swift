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
        return .topicList(TopicListRequest.with {
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
      id: \.id
    )

    return Self.init(forum: forum, dataSource: dataSource)
  }

  var body: some View {
    Group {
      if dataSource.items.isEmpty {
        ProgressView()
          .onAppear { dataSource.initialLoad() }
      } else {
        List {
          ForEach(dataSource.items, id: \.id) { topic in
            NavigationLink(destination: TopicDetailsView.build(topic: topic)) {
              TopicRowView(topic: topic, useTopicPostDate: true)
            } .onAppear { dataSource.loadMoreIfNeeded(currentItem: topic) }
          }
        }
        #if os(iOS)
          .listStyle(GroupedListStyle())
        #endif
      }
    } .navigationTitle("Recommended Topics")
  }
}
