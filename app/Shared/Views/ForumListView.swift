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
  @StateObject var searchModel = SearchModel<Forum>()

  @State var categories = [Category]()
  @State var favoriteEditing = false

  // HACK: do not use @Environment, which causes some sheets (like PostReplyView) popped unexpectedly
  @State var editMode = EditMode.inactive

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
        ForEach(favorites.favoriteForums, id: \.hashIdentifiable) { forum in
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
            ForEach(category.forums, id: \.hashIdentifiable) { forum in
              buildNormalLink(forum)
            }
          }
        }
      }
    }
  }

  @ViewBuilder
  var filterMenu: some View {
    if editMode == .active {
      EditButton().environment(\.editMode, $editMode)
    } else {
      Menu {
        Section {
          Button(action: { withAnimation { editMode = .active } }) {
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
  }

  @ViewBuilder
  var index: some View {
    List {
      favoritesSection
      if favorites.filterMode == .all {
        allForumsSection
      }
    } .environment(\.editMode, $editMode)
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
    )
    #if os(iOS)
      .onCancel { DispatchQueue.main.async { withAnimation { searchModel.text.removeAll() } } }
    #endif
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
    .modifier(DoubleItemsToolbarModifier(firstPlacement: .navigationBarLeading,
      buildFirst: { UserMenuView() },
      buildSecond: { filterMenu }
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
