//
//  SubforumListView.swift
//  NGA
//
//  Created by Bugen Zhao on 7/3/21.
//

import Foundation
import SwiftUI

struct SubforumListView: View {
  @StateObject var favorites = FavoriteForumsStorage.shared

  let forum: Forum
  let subforums: [Subforum]
  let refresh: () -> Void
  let onNavigateToForum: (Forum) -> Void

  func setSubforumFilter(show: Bool, subforum: Subforum) {
    logicCallAsync(.subforumFilter(.with {
      $0.operation = show ? .show : .block
      $0.forumID = forum.id.fid
      $0.subforumFilterID = subforum.filterID
    })) { (response: SubforumFilterResponse) in
      refresh()
    }
  }

  @ViewBuilder
  func buildLink(_ subforum: Subforum) -> some View {
    let forum = subforum.forum
    let isFavorite = favorites.isFavorite(id: forum.id)

    Button(action: { onNavigateToForum(forum) }) {
      HStack {
        Image(systemName: subforum.selected || !subforum.filterable ? "checkmark.circle.fill" : "circle")
          .onTapGesture {
          if subforum.filterable {
            setSubforumFilter(show: !subforum.selected, subforum: subforum)
          }
        }
          .foregroundColor(subforum.filterable ? .accentColor : .secondary)

        ForumRowView(forum: forum, isFavorite: isFavorite)
      }
        .modifier(FavoriteModifier(
        isFavorite: favorites.isFavorite(id: forum.id),
        toggleFavorite: { favorites.toggleFavorite(forum: forum) }
        ))
    }
  }

  var body: some View {
    List {
      Section(footer: Text("Press and hold a subforum to mark it as favorite.")) {
        ForEach(subforums, id: \.forum.idDescription) { subforum in
          buildLink(subforum)
        }
      }
    }
      .navigationTitle("Subforums of \(forum.name)")
    #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
        .listStyle(InsetGroupedListStyle())
    #endif
  }
}
