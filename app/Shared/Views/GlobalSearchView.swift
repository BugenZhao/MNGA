//
//  GlobalSearchView.swift
//  MNGA
//
//  Created by Bugen Zhao on 2021/11/1.
//

import Foundation
import SwiftUI
import SwiftUIX

struct DataSource {
  let forum: PagingDataSource<ForumSearchResponse, Forum>
  let topic: PagingDataSource<TopicSearchResponse, Topic>
  let user: PagingDataSource<RemoteUserResponse, User>
}

class GlobalSearchModel: SearchModel<DataSource> {
  override func buildDataSource(text: String) -> DataSource {
    DataSource(
      forum: .init(
        buildRequest: { _ in
          .forumSearch(.with {
            $0.key = text
          })
        },
        onResponse: { response in
          let items = response.forums
          return (items, 1)
        },
        id: \.idDescription
      ),

      topic: .init(
        buildRequest: { page in
          .topicSearch(.with {
            $0.key = text
            $0.searchContent = true
            $0.page = UInt32(page)
          })
        },
        onResponse: { response in
          let items = response.topics
          let pages = Int(response.pages)
          return (items, pages)
        },
        id: \.id
      ),

      user: .init(
        buildRequest: { _ in
          .remoteUser(.with {
            $0.userName = text
          })
        },
        onResponse: { response in
          if response.hasUser {
            ([response.user], 1)
          } else {
            ([], 1)
          }
        },
        id: \.id
      )
    )
  }
}

struct ForumSearchView: View {
  @ObservedObject var dataSource: PagingDataSource<ForumSearchResponse, Forum>

  @ViewBuilder
  func buildLink(_ forum: Forum) -> some View {
    ForumRowLinkView(forum: forum, showFavorite: true)
  }

  var body: some View {
    Group {
      if dataSource.notLoaded {
        ProgressView()
          .onAppear { dataSource.initialLoad() }
      } else {
        List {
          Section(header: Text("Search Results")) {
            ForEachOrEmpty(dataSource.items, id: \.id) { forum in
              buildLink(forum)
            }
          }
        }
      }
    }.navigationTitle("Forum Search")
  }
}

struct UserSearchView: View {
  @ObservedObject var dataSource: PagingDataSource<RemoteUserResponse, User>

  var body: some View {
    Group {
      if dataSource.notLoaded {
        ProgressView()
          .onAppear { dataSource.initialLoad() }
      } else {
        List {
          Section(header: Text("Search Results")) {
            ForEachOrEmpty(dataSource.items, id: \.id) { user in
              NavigationLink(destination: UserProfileView.build(user: user)) {
                UserView(user: user, style: .huge)
              }
            }
          }
        }
      }
    }.navigationTitle("User Search")
  }
}

struct GlobalSearchView: View {
  @ObservedObject var model: GlobalSearchModel

  var body: some View {
    List {
      if let ds = model.dataSource {
        Section(header: Text("Search \"\(model.text)\" in...")) {
          NavigationLink(destination: ForumSearchView(dataSource: ds.forum)) {
            Label("All Forums", systemImage: "square.stack.3d.down.right")
          }.isDetailLink(false) // show in the same stack
          NavigationLink(destination: TopicSearchView(dataSource: ds.topic).navigationTitle("Topic Search")) {
            Label("All Topics", systemImage: "doc.richtext")
          }
          // FIXME: the api is broken
          // NavigationLink(destination: UserSearchView(dataSource: ds.user)) {
          //   Label("All Users", systemImage: "person.2")
          // }.isDetailLink(false)
        }
      }
    }.mayInsetGroupedListStyle()
      // Auto commit (then build a new data source) on type, so that user don't need to press enter.
      .onChange(of: model.text, initial: true) { model.commit() }
  }
}
