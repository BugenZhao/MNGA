//
//  ForumSearchView.swift
//  NGA
//
//  Created by Bugen Zhao on 7/12/21.
//

import Foundation
import SwiftUI

struct ForumSearchView: View {
  @StateObject var favorites = FavoriteForumsStorage()
  @EnvironmentObject var model: SearchModel<Forum>

  @State var isLoading = false

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
      ForEach(model.results, id: \.hashIdentifiable) { forum in
        buildLink(forum)
      }
    } .onReceive(model.$commitFlag) { _ in self.doSearch() }
  }

  func doSearch() {
    if isLoading { return }
    isLoading = true

    logicCallAsync(.forumSearch(.with { $0.key = model.text }))
    { (response: ForumSearchResponse) in
      withAnimation {
        model.results = response.forums
        isLoading = false
      }
    }
  }
}
