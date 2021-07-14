//
//  HotTopicListView.swift
//  NGA
//
//  Created by Bugen Zhao on 7/5/21.
//

import Foundation
import SwiftUI
import Combine

class HotTopicDataSource: PagingDataSource<HotTopicListResponse, Topic> {
  @Published var range: HotTopicListRequest.DateRange = .day {
    didSet { self.refresh(animated: true) }
  }

  init(forum: Forum) {
    super.init(
      buildRequest: nil,
      onResponse: { response in
        let items = response.topics
        return (items, 1)
      },
      id: \.id
    )

    self.buildRequest = { _ in
      return .hotTopicList(HotTopicListRequest.with {
        $0.id = forum.id
        $0.range = self.range
        $0.fetchPageLimit = 5
      })
    }
  }
}

struct HotTopicListView: View {
  let forum: Forum

  @StateObject var dataSource: HotTopicDataSource
  
  static func build(forum: Forum) -> Self {
    return Self.init(forum: forum, dataSource: .init(forum: forum))
  }

  @ViewBuilder
  var rangeMenu: some View {
    Menu {
      Section {
        Picker(selection: $dataSource.range.animation(), label: Text("Range")) {
          ForEach(HotTopicListRequest.DateRange.allCases, id: \.rawValue) { range in
            HStack {
              Text(range.description)
              Spacer()
              Image(systemName: range.icon)
            } .tag(range)
          }
        }
      }
    } label: {
      Label("Range", systemImage: "calendar")
    } .imageScale(.large)

  }

  var body: some View {
    Group {
      if dataSource.items.isEmpty {
        ProgressView()
      } else {
        List {
          Section(header: Text(dataSource.range.description)) {
            ForEach(dataSource.items, id: \.id) { topic in
              NavigationLink(destination: TopicDetailsView.build(topic: topic)) {
                TopicRowView(topic: topic)
              }
            }
          }
        }
        #if os(iOS)
          .listStyle(GroupedListStyle())
        #endif
      }
    } .navigationTitle("Hot Topics")
      .modifier(SingleItemToolbarModifier { rangeMenu })
      .onAppear { dataSource.initialLoad() }
  }
}
