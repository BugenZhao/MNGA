//
//  SubforumListView.swift
//  NGA
//
//  Created by Bugen Zhao on 7/3/21.
//

import Foundation
import SwiftUI

struct SubforumRowView: View {
  let isFavorite: Bool
  @Binding var subforum: Subforum

  var body: some View {
    HStack {
      ForumRowView(forum: subforum.forum, isFavorite: isFavorite)

      Group {
        if subforum.filterable {
          Toggle(isOn: $subforum.selected) {}
        } else {
          Toggle(isOn: .constant(true)) {}.disabled(true)
        }
      }
      .labelsHidden()
      .tint(.accentColor)
    }
  }
}

struct SubforumListView: View {
  @StateObject var favorites = FavoriteForumsStorage.shared

  let forum: Forum
  // Marked as @State instead of @Binding since it's not actually synced with parent.
  // On toggling, a request will be sent to server, and we will be refreshed.
  @State var subforums: [Subforum]
  let refresh: () -> Void
  let onNavigateToForum: (Forum) -> Void

  func setSubforumFilter(show: Bool, subforum: Subforum) {
    logicCallAsync(.subforumFilter(.with {
      $0.operation = show ? .show : .block
      $0.forumID = forum.id.fid
      $0.subforumFilterID = subforum.filterID
    })) { (_: SubforumFilterResponse) in
      refresh()
      HapticUtils.play(type: .success)
    }
  }

  @ViewBuilder
  func buildLink(_ subforumBinding: Binding<Subforum>) -> some View {
    let subforum = subforumBinding.wrappedValue
    let forum = subforum.forum
    let isFavorite = favorites.isFavorite(id: forum.id)

    Button(action: { onNavigateToForum(forum) }) {
      SubforumRowView(isFavorite: isFavorite, subforum: subforumBinding)
        .onChange(of: subforum.selected) { setSubforumFilter(show: $1, subforum: subforum) }
    }.modifier(FavoriteModifier(forum: forum))
  }

  var body: some View {
    List {
      ForEachOrEmpty($subforums, id: \.wrappedValue.forum.idDescription) { subforum in
        buildLink(subforum)
      }
    }
    #if os(iOS)
    .listStyle(InsetGroupedListStyle())
    #endif
  }
}
