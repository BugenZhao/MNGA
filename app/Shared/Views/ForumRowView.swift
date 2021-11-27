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
      ForumIconView(iconURL: forum.iconURL)

      HStack {
        Text(forum.name.localized)
          .foregroundColor(.primary)
        if case .stid(_) = forum.id.id {
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
