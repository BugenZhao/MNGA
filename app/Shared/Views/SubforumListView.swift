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

  let forum: Forum
  let subforums: [Subforum]
  let refresh: () -> Void

  func setSubforumFilter(show: Bool, subforum: Subforum) {
    logicCallAsync(.subforumFilter(.with {
      $0.operation = show ? .show : .block
      $0.forumID = forum.fid
      $0.subforumFilterID = subforum.filterID
    })) { (response: SubforumFilterResponse) in
      refresh()
    }
  }

  @ViewBuilder
  func buildLink(_ subforum: Subforum) -> some View {
    let forum = subforum.forum
    let isFavorite = favorites.isFavorite(id: forum.id!)

    NavigationLink(destination: TopicListView(forum: forum)) {
      HStack {
        Image(systemName: subforum.selected || !subforum.filterable ? "checkmark.circle.fill" : "circle")
          .onTapGesture {
          if subforum.filterable {
            setSubforumFilter(show: !subforum.selected, subforum: subforum)
          }
        }
          .foregroundColor(subforum.filterable ? .accentColor : .secondary)

        ForumView(forum: forum, isFavorite: isFavorite)
      }
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
      Section(footer: Text("Press and hold a subforum to mark it as favorite.")) {
        ForEach(subforums, id: \.hashIdentifiable) { subforum in
          buildLink(subforum)
        }
      }
    } .navigationBarTitle("Subforums of \(forum.name)", displayMode: .inline)
      .listStyle(InsetGroupedListStyle())
  }
}
