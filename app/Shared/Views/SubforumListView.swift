//
//  SubforumListView.swift
//  NGA
//
//  Created by Bugen Zhao on 7/3/21.
//

import Foundation
import SwiftUI

struct SubforumListView: View {
  @StateObject var favorites = FavoriteForumsStorage()

  let subforums: [Subforum]

  @ViewBuilder
  func buildLink(_ subforum: Subforum) -> some View {
    let forum = subforum.forum
    let isFavorite = favorites.isFavorite(id: forum.id!)

    NavigationLink(destination: TopicListView(forum: forum)) {
      ForumView(forum: forum, isFavorite: isFavorite)
        .contextMenu(ContextMenu(menuItems: {
        Button(action: {
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation { favorites.toggleFavorite(forum: forum) }
          }
        }) {
          let text: LocalizedStringKey = isFavorite ? "Remove from Favorites" : "Mark as Favorite"
          let image = isFavorite ? "star.slash.fill" : "star"
          Label(text, systemImage: image)
        }
      }))
    }
  }

  var body: some View {
    List {
      ForEach(subforums, id: \.hashIdentifiable) { subforum in
        buildLink(subforum)
      }
    } .navigationTitle("Subforums")
      .navigationBarTitleDisplayMode(.inline)
      .listStyle(InsetGroupedListStyle())
  }
}
