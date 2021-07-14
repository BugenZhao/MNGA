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
        return .favoriteTopicList(.with {
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
    List {
      ForEach(dataSource.items, id: \.hashIdentifiable) { topic in
        NavigationLink(destination: TopicDetailsView.build(topic: topic)) {
          TopicRowView(topic: topic)
            .onAppear { dataSource.loadMoreIfNeeded(currentItem: topic) }
        }
      }
    } .navigationTitle("Favorite Topics")
      .onAppear { dataSource.initialLoad() }
    #if os(iOS)
      .listStyle(GroupedListStyle())
    #endif
  }
}

