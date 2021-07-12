//
//  ForumRowView.swift
//  NGA
//
//  Created by Bugen Zhao on 7/5/21.
//

import Foundation
import SwiftUI
import SDWebImageSwiftUI

struct ForumRowView: View {
  let forum: Forum
  let isFavorite: Bool

  var body: some View {
    HStack {
      let defaultIcon = Image("default_forum_icon")

      if let url = URL(string: forum.iconURL) {
        WebImage(url: url)
          .resizable()
          .placeholder(defaultIcon)
          .frame(width: 28, height: 28)
      } else {
        defaultIcon
          .resizable()
          .frame(width: 28, height: 28)
      }

      HStack {
        Text(forum.name)
          .foregroundColor(.primary)
        if case .stid(_) = forum.id.id {
          Image(systemName: "arrow.uturn.right")
            .font(.footnote)
            .foregroundColor(.secondary)
        }
        Spacer()

        HStack {
          Text(forum.info)
            .multilineTextAlignment(.trailing)
            .font(.footnote)
          if isFavorite {
            Text(Image(systemName: "star.fill"))
              .font(.caption2)
          }
        } .foregroundColor(.secondary)
      }
    }
  }
}

struct FavoriteModifier: ViewModifier {
  let isFavorite: Bool
  let toggleFavorite: () -> Void

  func body(content: Content) -> some View {
    content
      .contextMenu(ContextMenu(menuItems: {
      Button(action: {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
          withAnimation { toggleFavorite() }
        }
      }) {
        let text: LocalizedStringKey = isFavorite ? "Remove from Favorites" : "Mark as Favorite"
        let image = isFavorite ? "star.slash.fill" : "star"
        Label(text, systemImage: image)
      }
    }))
  }
}
