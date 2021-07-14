//
//  ForumListView.swift
//  NGA
//
//  Created by Bugen Zhao on 6/30/21.
//

import Foundation
import SwiftUI
import SwiftUIX

struct ForumListView: View {
  @StateObject var favorites = FavoriteForumsStorage()
  @StateObject var searchModel = SearchModel<Forum>()

  @State var categories = [Category]()

  @ViewBuilder
  func buildLink(_ forum: Forum, inFavoritesSection: Bool = true) -> some View {
    let isFavorite = favorites.isFavorite(id: forum.id)

    NavigationLink(destination: TopicListView.build(forum: forum)) {
      ForumRowView(forum: forum, isFavorite: inFavoritesSection && isFavorite)
        .modifier(FavoriteModifier(
        isFavorite: isFavorite,
        toggleFavorite: { favorites.toggleFavorite(forum: forum) }
        ))
    }
  }

  var favoritesSection: some View {
    Section(header: Text("Favorites").font(.subheadline).fontWeight(.medium)) {
      if favorites.favoriteForums.isEmpty {
        HStack {
          Spacer()
          Text("No Favorites")
            .font(.footnote)
            .foregroundColor(.secondary)
          Spacer()
        }
      } else {
        ForEach(favorites.favoriteForums, id: \.hashIdentifiable) { forum in
          buildLink(forum, inFavoritesSection: false)
        } .onDelete { offsets in
          favorites.favoriteForums.remove(atOffsets: offsets)
        }
      }
    }
  }

  var allForumsSection: some View {
    Group {
      if categories.isEmpty {
        HStack {
          Spacer()
          ProgressView()
          Spacer()
        }
      } else {
        ForEach(categories, id: \.id) { category in
          Section(header: Text(category.name).font(.subheadline).fontWeight(.medium)) {
            ForEach(category.forums, id: \.hashIdentifiable) { forum in
              buildLink(forum)
            }
          }
        }
      }
    }
  }

  @ViewBuilder
  var filterMenu: some View {
    Menu {
      Section {
        Picker(selection: $favorites.filterMode.animation(), label: Text("Filters")) {
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
    } .imageScale(.large)
  }

  @ViewBuilder
  var index: some View {
    List {
      favoritesSection
      if favorites.filterMode == .all {
        allForumsSection
      }
    }
  }

  @ViewBuilder
  var search: some View {
    ForumSearchView()
      .environmentObject(self.searchModel)
  }

  var searchBar: SearchBar {
    SearchBar(
      NSLocalizedString("Search Forums", comment: ""),
      text: $searchModel.text,
      isEditing: $searchModel.isEditing.animation(),
      onCommit: { searchModel.commitFlag += 1 }
    ) .onCancel { DispatchQueue.main.async { withAnimation { searchModel.text.removeAll() } } }
  }

  var body: some View {
    VStack {
      if searchModel.isSearching { search }
      else { index }
    } .onAppear { loadData() }
      .navigationTitle("Forums")
    #if os(iOS)
      .navigationSearchBar { searchBar }
    #endif
    .modifier(DoubleItemsToolbarModifier(
      buildLeading: { UserMenuView() },
      buildTrailing: { filterMenu }
      ))
  }

  func loadData() {
    guard categories.isEmpty else { return }

    logicCallAsync(.forumList(.with { _ in }))
    { (response: ForumListResponse) in
      withAnimation {
        categories = response.categories
      }
    }
  }
}

struct ForumListView_Previews: PreviewProvider {
  static var previews: some View {
    AuthedPreview {
      NavigationView {
        ForumListView()
      }
    }
  }
}
