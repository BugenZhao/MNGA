//
//  UserProfileView.swift
//  UserProfileView
//
//  Created by Bugen Zhao on 2021/9/10.
//

import Foundation
import SwiftUI
import SDWebImageSwiftUI

struct UserProfileView: View {
  typealias DataSource = PagingDataSource<UserTopicListResponse, Topic>

  enum Tab: LocalizedStringKey, CaseIterable {
    case topics = "Topics"
    case replies = "Replies"
  }

  let user: User

  @StateObject var dataSource: DataSource
  @State var tab = Tab.topics

  static func build(user: User) -> Self {
    let dataSource = DataSource(
      buildRequest: { page in
        return .userTopicList(UserTopicListRequest.with {
          $0.authorID = user.id
        })
      },
      onResponse: { response in
        let items = response.topics
        let pages = response.pages
        return (items, Int(pages))
      },
      id: \.id
    )
    return Self.init(user: user, dataSource: dataSource)
  }

  @ViewBuilder
  var list: some View {
    switch self.tab {
    case .topics:
      Section(header: Text("\(user.name)'s Topics")) {
        if dataSource.items.isEmpty {
          LoadingRowView()
            .onAppear { dataSource.initialLoad() }
        } else {
          ForEach(dataSource.items, id: \.id) { topic in
            NavigationLink(destination: TopicDetailsView.build(topic: topic)) {
              TopicRowView(topic: topic)
            } .onAppear { dataSource.loadMoreIfNeeded(currentItem: topic) }
          }
        }
      }
    case .replies:
      Text("test")
    }
  }

  var picker: some ToolbarContent {
    ToolbarItem(placement: .bottomBar) {
      Picker("Tab", selection: $tab.animation()) {
        ForEach(Tab.allCases, id: \.hashIdentifiable) {
          Text($0.rawValue).tag($0)
        }
      } .pickerStyle(.segmented)
    }
  }

  var body: some View {
    List {
      Section(header: Text("User Profile")) {
        UserView(user: user, style: .huge)
      }

      if !user.id.isEmpty {
        list
      }
    }
      .toolbar { picker }
    #if os(iOS)
      .listStyle(GroupedListStyle())
        .pullToRefresh(isShowing: .constant(dataSource.isRefreshing)) { dataSource.refresh() }
    #endif
      .navigationTitle(user.name)
      .navigationBarTitleDisplayMode(.inline)
  }
}
