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
  @StateObject var searchModel = GlobalSearchModel()
  @StateObject var prefs = PreferencesStorage.shared

  @State var categories = [Category]()

  // HACK: do not use @Environment, which causes some sheets (like PostReplyView) popped unexpectedly
  @State var editMode = EditMode.inactive

  @ViewBuilder
  func buildFavoriteSectionLink(_ forum: Forum) -> some View {
    ForumRowLinkView(forum: forum, showFavorite: false)
  }

  @ViewBuilder
  func buildNormalLink(_ forum: Forum) -> some View {
    ForumRowLinkView(forum: forum, showFavorite: true)
  }

  var favoritesSection: some View {
    Section(header: Text("Favorites").font(.subheadline).fontWeight(.medium)) {
      if favorites.favoriteForums.isEmpty {
        HStack {
          Spacer()
          VStack(alignment: .center) {
            Text("No Favorites")
              .font(.callout)
            Spacer().height(2)
            Text("Swipe a forum to mark it as favorite")
              .font(.footnote)
          }.foregroundColor(.secondary)
          Spacer()
        }
      } else {
        ForEach(favorites.favoriteForums, id: \.idDescription) { forum in
          buildFavoriteSectionLink(forum)
        }.onDelete { offsets in
          favorites.favoriteForums.remove(atOffsets: offsets)
        }.onMove { from, to in
          favorites.favoriteForums.move(fromOffsets: from, toOffset: to)
        }
      }
    }
  }

  var filteredCategories: [Category] {
    categories.filter { !(prefs.hideMNGAMeta && $0.id == "mnga") }
  }

  var allForumsSection: some View {
    Group {
      if categories.isEmpty {
        LoadingRowView()
      } else {
        ForEach(filteredCategories, id: \.id) { category in
          Section(header: Text(category.name).font(.subheadline).fontWeight(.medium)) {
            ForEach(category.forums, id: \.idDescription) { forum in
              buildNormalLink(forum)
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
        Button(action: { editMode = .active }) {
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
    }.imageScale(.large)
  }

  @ViewBuilder
  var filter: some View {
    if editMode == .active {
      EditButton().environment(\.editMode, $editMode)
    } else {
      filterMenu
    }
  }

  @ViewBuilder
  var index: some View {
    List {
      favoritesSection
      if favorites.filterMode == .all {
        allForumsSection
          .environment(\.editMode, .constant(.inactive))
      }
    }.environment(\.editMode, $editMode)
  }

  var body: some View {
    Group {
      if searchModel.text != "" {
        GlobalSearchView(model: searchModel)
      } else {
        index
      }
    }
    .searchable(model: searchModel, prompt: "Search".localized)
    .onAppear { loadData() }
    .navigationTitle("MNGA")
    .compatForumListListStyle()
    .toolbar {
      ToolbarItem(placement: .mayNavigationBarLeadingOrAction) { UserMenuView() }
      ToolbarItemGroup(placement: .mayNavigationBarTrailing) { filter }
    }
  }

  func loadData() {
    guard categories.isEmpty else { return }

    logicCallAsync(.forumList(.with { _ in })) { (response: ForumListResponse) in
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
