//
//  ForumSearchView.swift
//  NGA
//
//  Created by Bugen Zhao on 7/12/21.
//

import Foundation
import SwiftUI

class ForumSearchModel: SearchModel<ForumSearchResponse, Forum> {
  override func buildDataSource(text: String) -> DataSource {
    DataSource(
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
    )
  }
}

struct ForumSearchView: View {
  @StateObject var favorites = FavoriteForumsStorage.shared
  @ObservedObject var dataSource: ForumSearchModel.DataSource

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
      ProgressView()
        .onAppear { dataSource.initialLoad() }
    } else {
      List {
        ForEach(dataSource.items, id: \.id) { forum in
          buildLink(forum)
        }
      }
    }
  }
}
