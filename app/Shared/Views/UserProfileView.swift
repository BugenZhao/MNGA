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

  let user: User

  @StateObject var dataSource: DataSource

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

  var body: some View {
    VStack(alignment: .leading) {
      if dataSource.items.isEmpty {
        ProgressView()
      } else {
        List {
          Section(header: Text("User Profile")) {
            UserView(user: user, style: .huge)
          }

          if !user.id.isEmpty {
            Section(header: Text("\(user.name)'s Topics")) {
              ForEach(dataSource.items, id: \.id) { topic in
                NavigationLink(destination: TopicDetailsView.build(topic: topic)) {
                  TopicRowView(topic: topic)
                } .onAppear { dataSource.loadMoreIfNeeded(currentItem: topic) }
              }
            }
          }
        }
        #if os(iOS)
          .listStyle(GroupedListStyle())
            .pullToRefresh(isShowing: .constant(dataSource.isRefreshing)) { dataSource.refresh() }
        #endif
      }
    }
      .onAppear { dataSource.initialLoad() }
      .navigationTitle(user.name)
  }
}
