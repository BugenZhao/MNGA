//
//  TopicHistoryListView.swift
//  NGA
//
//  Created by Bugen Zhao on 7/5/21.
//

import Foundation
import SwiftUI
import SwiftUIX

struct TopicHistoryListView: View {
  @StateObject var dataSource: PagingDataSource<TopicHistoryResponse, TopicSnapshot>

  @State var searchText = ""
  @State var isSearching = false

  init() {
    let dataSource = PagingDataSource<TopicHistoryResponse, TopicSnapshot>(
      buildRequest: { _ in
        return .topicHistory(TopicHistoryRequest.with {
          $0.limit = 1000
        })
      },
      onResponse: { response in
        let items = response.topics
        return (items, 1)
      },
      id: \.topicSnapshot.id
    )
    self._dataSource = StateObject(wrappedValue: dataSource)
  }

  var body: some View {
    List {
      let items = dataSource.items.filter { searchText.isEmpty || $0.topicSnapshot.subjectFull.contains(searchText) }
      ForEach(items, id: \.hashIdentifiable) { snapshot in
        let topic = snapshot.topicSnapshot
        NavigationLink(destination: TopicDetailsView(topic: topic)) {
          TopicView(topic: topic)
        }
      }
    } .navigationTitle("History")
      .onAppear { dataSource.initialLoad() }
    #if os(iOS)
      .navigationSearchBar {
        SearchBar(
          NSLocalizedString("Search History", comment: ""),
          text: $searchText,
          isEditing: $isSearching.animation()
        )
      }
        .listStyle(GroupedListStyle())
    #endif
  }
}
