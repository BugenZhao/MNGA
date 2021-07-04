//
//  TopicHistoryListView.swift
//  NGA
//
//  Created by Bugen Zhao on 7/5/21.
//

import Foundation
import SwiftUI

struct TopicHistoryListView: View {
  @State var histories: [TopicSnapshot] = []

  var body: some View {
    let list = List {
      ForEach(histories, id: \.hashIdentifiable) { snapshot in
        let topic = snapshot.topicSnapshot
        NavigationLink(destination: TopicDetailsView(topic: topic)) {
          TopicView(topic: topic)
        }
      }
    } .navigationTitle("History")
      .onAppear { loadData() }

    #if os(iOS)
      list
        .listStyle(GroupedListStyle())
    #else
      list
    #endif
  }
  
  func loadData() {
    if self.histories.isEmpty {
      logicCallAsync(.topicHistory(.with {
        $0.limit = 1000
      })) { (response: TopicHistoryResponse) in
        print(response)
        withAnimation {
          self.histories = response.topics
        }
      }
    }
  }
}
