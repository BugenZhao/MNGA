//
//  ForumRowView.swift
//  NGA
//
//  Created by Bugen Zhao on 7/5/21.
//

import Foundation
import SDWebImageSwiftUI
import SwiftUI

struct ForumRowLinkView: View {
  let forum: Forum
  let showFavorite: Bool

  // With this counter hack, the topic list will be refreshed every time we navigate into.
  // Once the `TopicListView` is pushed into the stack, the value of `hack` will be changed,
  // causing the whole link to be recreated with a different id. This will then create a
  // new destination `TopicListView`, making the following navigation to be a "fresh" one.
  @State var hack = 0

  @StateObject var favorites = FavoriteForumsStorage.shared

  var isFavorite: Bool {
    favorites.isFavorite(id: forum.id)
  }

  @ViewBuilder
  var link: some View {
    CrossStackNavigationLinkHack(id: forum.id, destination: {
      TopicListView.build(forum: forum)
        .onAppearOnce { hack += 1 }
    }) {
      EmptyView().id(hack)
      ForumRowView(forum: forum, isFavorite: showFavorite && isFavorite)
    }
  }

  var body: some View {
    if showFavorite {
      link
        .modifier(FavoriteModifier(forum: forum))
    } else {
      link
    }
  }
}

struct ForumRowView: View {
  let forum: Forum
  let isFavorite: Bool

  var body: some View {
    HStack {
      ForumIconView(iconURL: forum.iconURL)

      HStack {
        Text(forum.name.localized)
          .foregroundColor(.primary)
        if case .stid = forum.id.id {
          Image(systemName: "arrow.uturn.right")
            .font(.footnote)
            .foregroundColor(.secondary)
        }
        Spacer()

        HStack {
          Text(forum.info.localized)
            .multilineTextAlignment(.trailing)
            .font(.footnote)
          if isFavorite {
            Text(Image(systemName: "star.fill"))
              .font(.caption2)
          }
        }.foregroundColor(.secondary)
      }
    }
  }
}

struct FavoriteModifier: ViewModifier {
  let forum: Forum

  @StateObject var favorites = FavoriteForumsStorage.shared

  func toggle() {
    withAnimation {
      favorites.toggleFavorite(forum: forum)
    }
  }

  func body(content: Content) -> some View {
    let isFavorite = favorites.isFavorite(id: forum.id)
    let image = isFavorite ? "star.slash.fill" : "star"
    let label: LocalizedStringKey = isFavorite ? "Remove from Favorites" : "Mark as Favorite"
    let tintColor: Color = isFavorite ? .gray : .accentColor

    content
      .swipeActions(edge: .trailing) {
        Button(action: toggle) {
          Label(label, systemImage: image)
        }.tint(tintColor)
      }
  }
}
