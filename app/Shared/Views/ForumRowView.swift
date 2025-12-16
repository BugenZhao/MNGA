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
  let asTopicShortcut: Topic?

  init(forum: Forum, showFavorite: Bool = true, asTopicShortcut: Topic? = nil) {
    self.forum = forum
    self.showFavorite = showFavorite
    self.asTopicShortcut = asTopicShortcut
  }

  // With this counter hack, the topic list will be refreshed every time we navigate into.
  // Once the `TopicListView` is pushed into the stack, the value of `hack` will be changed,
  // causing the whole link to be recreated with a different id. This will then create a
  // new destination `TopicListView`, making the following navigation to be a "fresh" one.
  @State var hack = 0

  @StateObject var favorites = FavoriteForumsStorage.shared

  var isFavorite: Bool {
    favorites.isFavorite(id: forum.id)
  }

  var navigationDestination: some View {
    TopicListView.build(forum: forum)
      .onAppearOnce { hack += 1 }
  }

  @ViewBuilder
  var label: some View {
    EmptyView().id(hack)
    ForumRowView(forum: forum, isFavorite: showFavorite && isFavorite, asTopicShortcut: asTopicShortcut)
  }

  @ViewBuilder
  var link: some View {
    if asTopicShortcut != nil {
      // If it's a shortcut, navigate within the same stack.
      NavigationLink(destination: navigationDestination) { label }
        .isDetailLink(false)
    } else {
      CrossStackNavigationLinkHack(id: forum.id, destination: { navigationDestination }) { label }
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
  let asTopicShortcut: Topic?

  init(forum: Forum, isFavorite: Bool = false, asTopicShortcut: Topic? = nil) {
    self.forum = forum
    self.isFavorite = isFavorite
    self.asTopicShortcut = asTopicShortcut
  }

  var icon: some View {
    ForumIconView(iconURL: forum.iconURL)
  }

  @ViewBuilder
  var name: some View {
    Text(forum.name.localized)
      .foregroundColor(.primary)
  }

  @ViewBuilder
  var stIndicator: some View {
    Group {
      if case .stid = forum.id.id {
        Image(systemName: "square.stack.3d.up")
      } else if asTopicShortcut != nil {
        // Always show an indicator for shortcuts.
        Image(systemName: "arrow.uturn.right")
      }
    }
    .font(.footnote)
    .foregroundColor(.secondary)
  }

  @ViewBuilder
  var infoAndFavorite: some View {
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

  var body: some View {
    if let topic = asTopicShortcut {
      HStack {
        TopicSubjectView(topic: topic)
        Spacer()
        stIndicator
        icon
      }
    } else {
      HStack {
        icon
        name
        stIndicator
        Spacer()
        infoAndFavorite
      }
    }
  }
}

struct FavoriteModifier: ViewModifier {
  let forum: Forum

  @StateObject var favorites = FavoriteForumsStorage.shared

  func toggle() {
    withAnimation {
      favorites.toggle(forum: forum)
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
