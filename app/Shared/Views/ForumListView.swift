//
//  ForumListView.swift
//  NGA
//
//  Created by Bugen Zhao on 6/30/21.
//

import Foundation
import SwiftUI
import RemoteImage

struct ForumView: View {
  let forum: Forum
  let isFavorite: Bool

  var body: some View {
    HStack {
      let defaultIcon = Image("default_forum_icon").resizable()

      if let url = URL(string: forum.iconURL) {
        RemoteImage(
          type: .url(url),
          errorView: { _ in defaultIcon },
          imageView: { image in
            image.resizable()
          },
          loadingView: { defaultIcon }
        ) .frame(width: 28, height: 28)
      } else {
        defaultIcon
      }

      HStack {
        Text(forum.name)
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

struct ForumListView: View {
  @StateObject var favorites = FavoriteForumsStorage()

  @State var categories = [Category]()

  public let defaultForum = Forum.with {
    $0.id = "-7"
    $0.fid = "-7"
    $0.name = "网事杂谈"
  }

  func buildLink(_ forum: Forum, showFavorite: Bool = true) -> some View {
    let isFavorite = favorites.isFavorite(id: forum.id)

    return NavigationLink(destination: TopicListView(forum: forum)) {
      ForumView(forum: forum, isFavorite: showFavorite && isFavorite)
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
    VStack {
      let list = List {

        Section(header: Text("Favorites").font(.subheadline).fontWeight(.medium)) {
          if favorites.favoriteForums.isEmpty {
            HStack {
              Spacer(); Text("No Favorites").font(.footnote).foregroundColor(.secondary); Spacer()
            }
          } else {
            ForEach(favorites.favoriteForums, id: \.id) { forum in
              buildLink(forum, showFavorite: false)
            }
          }
        } .onAppear { loadData() }

        if favorites.filterMode == .all {
          if categories.isEmpty {
            HStack {
              Spacer(); ProgressView(); Spacer()
            }
          } else {
            ForEach(categories, id: \.id) { category in
              Section(header: Text(category.name).font(.subheadline).fontWeight(.medium)) {
                ForEach(category.forums, id: \.id) { forum in
                  buildLink(forum)
                }
              }
            }
          }
        }

      }
      #if os(iOS)
        list
      #else
        list
      #endif
    } .navigationTitle("Forums")
      .toolbar {
      ToolbarItem() {
        Menu {
          Section {
            Picker(selection: $favorites.filterMode.animation(), label: Text("Filter Mode")) {
              ForEach(FavoriteForumsStorage.FilterMode.allCases, id: \.rawValue) { mode in
                HStack {
                  Text(LocalizedStringKey(mode.rawValue))
                  Spacer()
                  Image(systemName: mode.icon)
                } .tag(mode)
              }
            }
          }
        } label: {
          Label("Filters", systemImage: favorites.filterMode.filterIcon)
        }
      }
    }
  }

  func loadData() {
    guard categories.isEmpty else { return }

    logicCallAsync(.forumList(.with { _ in }))
    { (response: ForumListResponse) in
      categories = response.categories
    }
  }
}

struct ForumListView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      ForumListView()
    }
  }
}
