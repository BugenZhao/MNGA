//
//  TopicListView.swift
//  NGA
//
//  Created by Bugen Zhao on 6/28/21.
//

import Foundation
import SwiftUI

struct TopicListView: View {
  @StateObject var dataSource: PagingDataSource<TopicListResponse, Topic>

  init() {
    let dataSource = PagingDataSource<TopicListResponse, Topic>(
      buildRequest: { page in
        return .topicList(TopicListRequest.with {
          $0.forumID = "-7"
          $0.page = UInt32(page)
        })
      },
      onResponse: { response in
        let items = response.topics
        let pages = response.pages
        return (items, Int(pages))
      },
      id: \.id
    )
    self._dataSource = StateObject(wrappedValue: dataSource)
  }

  var body: some View {
    VStack {
      if dataSource.items.isEmpty {
        ProgressView()
      } else {
        List {
          ForEach(dataSource.items, id: \.id) { topic in
            let destination = NavigationLazyView(TopicDetailsView(topic: topic))

            NavigationLink(destination: destination) {
              TopicView(topic: topic)
                .onAppear { dataSource.loadMoreIfNeeded(currentItem: topic) }
            }
          }
        }
      }
    }
      .navigationTitle("Topics")
      .toolbar {
      ToolbarItem {
        Button(action: { dataSource.refresh() }) {
          Image(systemName: "arrow.clockwise.circle")
        }
      }
    }
  }
}
