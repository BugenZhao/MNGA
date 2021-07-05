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
    let list = List {
      ForEach(dataSource.items, id: \.hashIdentifiable) { snapshot in
        let topic = snapshot.topicSnapshot
        NavigationLink(destination: TopicDetailsView(topic: topic)) {
          TopicView(topic: topic)
        }
      }
    } .navigationTitle("History")
      .onFirstAppear { dataSource.initialLoad() }

    #if os(iOS)
      list
        .listStyle(GroupedListStyle())
    #else
      list
    #endif
  }
}
