//
//  TopicSearchView.swift
//  MNGA
//
//  Created by Bugen Zhao on 2021/10/21.
//

import Foundation
import SwiftUI
import SwiftUIX

class TopicSearchModel: SearchModel<TopicSearchResponse, Topic> {
  let id: ForumId

  init(id: ForumId) {
    self.id = id
  }

  override func buildDataSource(text: String) -> DataSource {
    DataSource(
      buildRequest: { page in
        return .topicSearch(.with {
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
    if dataSource.items.isEmpty {
      ProgressView()
        .onAppear { dataSource.initialLoad() }
    } else {
      List {
        Section(header: Text("Search Results")) {
          ForEach($dataSource.items, id: \.id) { topic in
            NavigationLink(destination: { TopicDetailsView.build(topicBinding: topic) }) {
              TopicRowView(topic: topic.w)
            } .onAppear { dataSource.loadMoreIfNeeded(currentItem: topic.w) }
          }
        }
      }
        .mayGroupedListStyle()
    }
  }
}
