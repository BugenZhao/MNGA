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

  @StateObject var favorites = FavoriteForumsStorage.shared

  var isFavorite: Bool {
    favorites.isFavorite(id: forum.id)
  }

  @ViewBuilder
  var link: some View {
    NavigationLink(destination: TopicListView.build(forum: forum)) {
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

  func body(content: Content) -> some View {
    content
      .swipeActions(edge: .trailing) {
        Button(action: { withAnimation { favorites.toggleFavorite(forum: forum) } }) {
          let isFavorite = favorites.isFavorite(id: forum.id)
          let image = isFavorite ? "star.slash.fill" : "star"
          Image(systemName: image)
        }.tint(.accentColor)
      }
  }
}
