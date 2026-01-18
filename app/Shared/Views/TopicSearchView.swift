//
//  TopicSearchView.swift
//  MNGA
//
//  Created by Bugen Zhao on 2021/10/21.
//

import Foundation
import SwiftUI
import SwiftUIX

class TopicSearchModel: SearchModel<PagingDataSource<TopicSearchResponse, Topic>> {
  let id: ForumId

  init(id: ForumId) {
    self.id = id
  }

  override func buildDataSource(text: String) -> DataSource {
    DataSource(
      buildRequest: { page in
        .topicSearch(.with {
          $0.id = self.id
          $0.key = text
          $0.searchContent = true
          $0.page = UInt32(page)
        })
      },
      onResponse: { response in
        let items = response.topics
        let pages = Int(response.pages)
        return (items, pages)
      },
      id: \.id
    )
  }
}

struct TopicSearchView: View {
  @ObservedObject var dataSource: TopicSearchModel.DataSource

  var body: some View {
    if dataSource.notLoaded {
      ProgressView()
        .onAppear { dataSource.initialLoad() }
    } else if dataSource.items.isEmpty {
      ContentUnavailableView("No Results", systemImage: "magnifyingglass")
    } else {
      List {
        Section(header: Text("Search Results")) {
          SafeForEach($dataSource.items, id: \.id) { topic in
            TopicRowLinkView(topic: topic)
              .onAppear { dataSource.loadMoreIfNeeded(currentItem: topic.w) }
          }
        }
      }
      .mayGroupedListStyle()
    }
  }
}
