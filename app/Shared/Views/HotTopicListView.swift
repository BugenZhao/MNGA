//
//  HotTopicListView.swift
//  NGA
//
//  Created by Bugen Zhao on 7/5/21.
//

import Foundation
import SwiftUI

struct HotTopicListInnerView: View {
  typealias DateRange = HotTopicListRequest.DateRange
  typealias DataSource = PagingDataSource<HotTopicListResponse, Topic>

  let forum: Forum
  let range: DateRange

  @StateObject var dataSource: DataSource

  static func build(forum: Forum, range: DateRange) -> Self {
    let dataSource = DataSource(
      buildRequest: { _ in
        .hotTopicList(HotTopicListRequest.with {
          $0.id = forum.id
          $0.range = range
          $0.fetchPageLimit = 5
        })
      },
      onResponse: { response in
        let items = response.topics
        return (items, 1)
      },
      id: \.id
    )

    return Self(forum: forum, range: range, dataSource: dataSource)
  }

  var body: some View {
    if dataSource.notLoaded {
      ProgressView()
        .onAppear { dataSource.initialLoad() }
    } else {
      List {
        Section(header: Text(range.description)) {
          ForEach($dataSource.items, id: \.id) { topic in
            NavigationLink(destination: TopicDetailsView.build(topicBinding: topic)) {
              TopicRowView(topic: topic.w)
            }
          }
        }
      }.mayGroupedListStyle()
    }
  }
}

struct HotTopicListView: View {
  let forum: Forum

  @State var range = HotTopicListRequest.DateRange.day

  static func build(forum: Forum) -> Self {
    Self(forum: forum)
  }

  @ViewBuilder
  var rangeMenu: some View {
    Menu {
      Section {
        Picker(selection: $range.animation(), label: Text("Range")) {
          ForEach(HotTopicListRequest.DateRange.allCases, id: \.rawValue) { range in
            HStack {
              Text(range.description)
              Spacer()
              Image(systemName: range.icon)
            }.tag(range)
          }
        }
      }
    } label: {
      Label("Range", systemImage: "calendar")
    }.imageScale(.large)
  }

  var body: some View {
    HotTopicListInnerView.build(forum: forum, range: range)
      .id(range)
      .navigationTitle("Hot Topics")
      .toolbarWithFix { ToolbarItem(placement: .mayNavigationBarTrailing) { rangeMenu } }
  }
}
