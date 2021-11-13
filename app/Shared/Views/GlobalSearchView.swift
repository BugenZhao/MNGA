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
  init() {
    super.init(commited: false)
  }

  override func buildDataSource(text: String) -> DataSource {
    DataSource(

      forum: .init(
        buildRequest: { _ in
          return .forumSearch(.with {
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
          return .topicSearch(.with {
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
          return .remoteUser(.with {
            $0.userName = text
          })
        },
        onResponse: { response in
          if response.hasUser {
            return ([response.user], 1)
          } else {
            return ([], 1)
          }
        },
        id: \.id
      )

    )
  }
}

struct ForumSearchView: View {
  @StateObject var favorites = FavoriteForumsStorage.shared
  @ObservedObject var dataSource: PagingDataSource<ForumSearchResponse, Forum>

  @ViewBuilder
  func buildLink(_ forum: Forum) -> some View {
    let isFavorite = favorites.isFavorite(id: forum.id)

    NavigationLink(destination: TopicListView.build(forum: forum)) {
      ForumRowView(forum: forum, isFavorite: isFavorite)
        .modifier(FavoriteModifier(
        isFavorite: isFavorite,
        toggleFavorite: { favorites.toggleFavorite(forum: forum) }
      ))
    }
  }

  var body: some View {
    List {
      if dataSource.notLoaded {
        LoadingRowView()
          .onAppear { dataSource.initialLoad() }
      } else {
        ForEach(dataSource.items, id: \.id) { forum in
          buildLink(forum)
        }
      }
    } .navigationTitleInline(key: "Forum Search")
  }
}

struct UserSearchView: View {
  @ObservedObject var dataSource: PagingDataSource<RemoteUserResponse, User>

  var body: some View {
    List {
      if dataSource.notLoaded {
        LoadingRowView()
          .onAppear { dataSource.initialLoad() }
      } else {
        ForEach(dataSource.items, id: \.id) { user in
          NavigationLink(destination: UserProfileView.build(user: user)) {
            UserView(user: user, style: .huge)
          }
        }
      }
    } .navigationTitleInline(key: "User Search")
  }
}


struct GlobalSearchView: View {
  enum Mode: Equatable {
    case topic
    case forum
    case user
  }

  @ObservedObject var model: GlobalSearchModel

  var body: some View {
    List {
      if let ds = model.dataSource {
        Section(header: Text("Search \"\(model.text)\" in...")) {
          NavigationLink(destination: ForumSearchView(dataSource: ds.forum)) {
            Label("All Forums", systemImage: "square.stack.3d.down.right")
          }
          NavigationLink(destination: TopicSearchView(dataSource: ds.topic).navigationTitleInline(key: "Topic Search")) {
            Label("All Topics", systemImage: "doc.richtext")
          }
          NavigationLink(destination: UserSearchView(dataSource: ds.user)) {
            Label("All Users", systemImage: "person.2")
          }
        }
      }
    } .mayInsetGroupedListStyle()
  }
}
