//
//  FavoriteTopicListView.swift
//  NGA
//
//  Created by Bugen Zhao on 7/14/21.
//

import Foundation
import SwiftUI

struct FavoriteTopicListView: View {
  typealias DataSource = PagingDataSource<FavoriteTopicListResponse, Topic>

  @StateObject var dataSource: DataSource

  @State var searchText = ""
  @State var isSearching = false

  static func build() -> Self {
    let dataSource = DataSource(
      buildRequest: { page in
        .favoriteTopicList(.with {
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

    return Self(dataSource: dataSource)
  }

  var body: some View {
    Group {
      if dataSource.notLoaded {
        ProgressView()
          .onAppear { dataSource.initialLoad() }
      } else {
        List {
          ForEach($dataSource.items, id: \.id) { topic in
            NavigationLink(destination: TopicDetailsView.build(topicBinding: topic)) {
              TopicRowView(topic: topic.w, dimmedSubject: false, showIndicators: false)
                .onAppear { dataSource.loadMoreIfNeeded(currentItem: topic.w) }
            }
          }.onDelete { indexSet in deleteFavorites(at: indexSet) }
        }
      }
    }
    .navigationTitle("Favorite Topics")
    .refreshable(dataSource: dataSource)
    .mayGroupedListStyle()
  }

  func deleteFavorites(at indexSet: IndexSet) {
    guard let firstIndex = indexSet.first else { return }
    let topic = dataSource.items[firstIndex] // FIXME: only first

    logicCallAsync(.topicFavor(.with {
      $0.topicID = topic.id
      $0.operation = .delete
    })) { (response: TopicFavorResponse) in
      if !response.isFavored { dataSource.items.remove(at: firstIndex) }
    }
  }
}
