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
  @StateObject var favorites = FavoriteForumsStorage.shared
  @StateObject var searchModel = ForumSearchModel()

  @State var categories = [Category]()
  @State var favoriteEditing = false

  #if os(iOS)
    // HACK: do not use @Environment, which causes some sheets (like PostReplyView) popped unexpectedly
    @State var editMode = EditMode.inactive
  #endif

  @ViewBuilder
  func buildFavoriteSectionLink(_ forum: Forum) -> some View {
    NavigationLink(destination: TopicListView.build(forum: forum)) {
      ForumRowView(forum: forum, isFavorite: false)
    }
  }

  @ViewBuilder
  func buildNormalLink(_ forum: Forum) -> some View {
    let isFavorite = favorites.isFavorite(id: forum.id)

    NavigationLink(destination: TopicListView.build(forum: forum)) {
      ForumRowView(forum: forum, isFavorite: isFavorite)
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
        ForEach(favorites.favoriteForums, id: \.idDescription) { forum in
          buildFavoriteSectionLink(forum)
        } .onDelete { offsets in
          favorites.favoriteForums.remove(atOffsets: offsets)
        } .onMove { from, to in
          favorites.favoriteForums.move(fromOffsets: from, toOffset: to)
          withAnimation { self.favoriteEditing = false }
        }
      }
    }
  }

  var allForumsSection: some View {
    Group {
      if categories.isEmpty {
        LoadingRowView()
      } else {
        ForEach(categories, id: \.id) { category in
          Section(header: Text(category.name).font(.subheadline).fontWeight(.medium)) {
            ForEach(category.forums, id: \.idDescription) { forum in
              buildNormalLink(forum)
            }
          }
        }
      }
    }
  }

  func setEditModeActive() {
    #if os(iOS)
      withAnimation { editMode = .active }
    #endif
  }

  @ViewBuilder
  var filterMenu: some View {
    Menu {
      Section {
        Button(action: { setEditModeActive() }) {
          Text("Edit Favorites")
        }
      }

      Section {
        Picker(selection: $favorites.filterMode.animation(), label: Text("Filters")) {
          ForEach(FavoriteForumsStorage.FilterMode.allCases, id: \.rawValue) { mode in
            Label(LocalizedStringKey(mode.rawValue), systemImage: mode.icon)
              .tag(mode)
          }
        }
      }
    } label: {
      Label("Filters", systemImage: favorites.filterMode.filterIcon)
    } .imageScale(.large)
  }

  @ViewBuilder
  var filter: some View {
    #if os(iOS)
      if editMode == .active {
        EditButton().environment(\.editMode, $editMode)
      } else {
        filterMenu
      }
    #else
      filterMenu
    #endif
  }

  @ViewBuilder
  var index: some View {
    List {
      favoritesSection
      if favorites.filterMode == .all {
        allForumsSection
      }
    }
    #if os(iOS)
      .environment(\.editMode, $editMode)
    #endif
  }

  @ViewBuilder
  var search: some View {
    ForumSearchView()
      .environmentObject(self.searchModel)
  }

  #if os(iOS)
    var searchBar: SearchBar {
      SearchBar(
        NSLocalizedString("Search Forums", comment: ""),
        text: $searchModel.text,
        onCommit: { searchModel.commit() }
      ) .onCancel { searchModel.cancel() }
    }
  #endif

  var body: some View {
    Group {
      if let dataSource = searchModel.dataSource { ForumSearchView(dataSource: dataSource) }
      else { index }
    } .onAppear { loadData() }
      .navigationTitle("Forums")
    #if os(iOS)
      .navigationSearchBar { searchBar }
        .navigationSearchBarHiddenWhenScrolling(false)
    #endif
    .toolbar {
      ToolbarItem(placement: .mayNavigationBarLeadingOrAction) { UserMenuView() }
      ToolbarItem(placement: .mayNavigationBarTrailing) { filter }
    }
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
