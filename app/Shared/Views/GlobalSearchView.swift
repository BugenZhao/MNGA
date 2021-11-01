//
//  GlobalSearchView.swift
//  MNGA
//
//  Created by Bugen Zhao on 2021/11/1.
//

import Foundation
import SwiftUI

struct DataSource {
  let forum: PagingDataSource<ForumSearchResponse, Forum>
  let topic: PagingDataSource<TopicSearchResponse, Topic>
}

class GlobalSearchModel: SearchModel<DataSource> {
  init() {
    super.init(commited: true)
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
      )

    )
  }
}

struct ForumSearchItemsView: View {
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
    if dataSource.notLoaded {
      LoadingRowView()
        .onAppear { dataSource.initialLoad() }
    } else {
      ForEach(dataSource.items, id: \.id) { forum in
        buildLink(forum)
      }
    }
  }
}


struct GlobalSearchView: View {
  enum Mode: Equatable {
    case topic
    case forum
    case user
  }

  @ObservedObject var model: GlobalSearchModel

  @State var mode: Mode?

  var body: some View {
    List {
      if mode == nil {
        Section(header: Text("Search \"\(model.text)\" in...")) {
          Button(action: { mode = .forum }) {
            Label("All Forums", systemImage: "square.stack.3d.down.right")
          }
          Button(action: { mode = .topic }) {
            Label("All Topics", systemImage: "doc.richtext")
          }
          Button(action: { mode = .user }) {
            Label("All Users", systemImage: "person.2")
          }
        }
      }

      if let ds = model.dataSource {
        switch mode {
        case .forum:
          Section(header: Text("Forums")) {
            ForumSearchItemsView(dataSource: ds.forum)
          }
        case .topic:
          Section(header: Text("Topics")) {
            TopicSearchItemsView(dataSource: ds.topic)
          }
        default:
          EmptyView()
        }
      }
    } .mayInsetGroupedListStyle()
      .onChange(of: mode) { _ in model.commit() }
  }
}
