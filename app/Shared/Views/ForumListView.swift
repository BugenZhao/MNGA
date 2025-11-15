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
  @EnvironmentObject var schemes: SchemesModel
  @EnvironmentObject var paywall: PaywallModel

  @StateObject var favorites = FavoriteForumsStorage.shared
  @StateObject var searchModel = GlobalSearchModel()
  @StateObject var prefs = PreferencesStorage.shared

  @State var categories = [Category]()

  @AppStorage("collapsedCategories") var collapsedCategories = JSONRepr(inner: Set<String>())

  // Only when a binding of `isExpanded` is provided, the section is collapsible.
  func isCategoryExpanded(_ id: String) -> Binding<Bool> {
    .init(
      get: { !collapsedCategories.inner.contains(id) },
      set: { if $0 { collapsedCategories.inner.remove(id) } else { collapsedCategories.inner.insert(id) } }
    )
  }

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
    Section("Favorites", isExpanded: isCategoryExpanded("MNGA-Favorites")) {
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
        // Hack for disordering after `onMove`
        .id(favorites.favoriteForums.hashValue)
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
          .task { await loadData() }
      } else {
        ForEach(filteredCategories, id: \.id) { category in
          Section(category.name, isExpanded: isCategoryExpanded(category.id)) {
            ForEach(category.forums, id: \.idDescription) { forum in
              buildNormalLink(forum)
            }
          }
        }
      }
    }
  }

  @ViewBuilder
  var filterIcon: some View {
    switch favorites.filterMode {
    case .favoritesOnly:
      Image(systemName: "line.horizontal.3.decrease.circle.fill")
        .foregroundColor(.accentColor)
        .scaleEffect(1.6)
    case .all:
      Image(systemName: "line.horizontal.3.decrease")
    }
  }

  @ViewBuilder
  var filterMenu: some View {
    Menu {
      Section {
        Button(action: { editMode = .active }) {
          Label("Edit Favorites", systemImage: "list.star")
        }
      }

      Section {
        Picker(selection: $favorites.filterMode.animation(), label: Text("Filters")) {
          ForEach(FavoriteForumsStorage.FilterMode.allCases, id: \.rawValue) { mode in
            Label(mode.rawValue.localized, systemImage: mode.icon)
              .tag(mode)
          }
        }
        .menuActionDismissBehavior(.disabled)
      }

      if favorites.filterMode == .all {
        Section {
          if collapsedCategories.inner.isEmpty {
            Button(action: { collapsedCategories.inner.formUnion(categories.map(\.id)) }) {
              Label("Collapse All Categories", systemImage: "chevron.up")
            }
          } else {
            Button(action: { collapsedCategories.inner.removeAll() }) {
              Label("Expand All Categories", systemImage: "chevron.down")
            }
          }
        }
      }
    } label: {
      filterIcon
    }
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
    }
    .environment(\.editMode, $editMode)
    // https://stackoverflow.com/a/79319001
    .animation(.default, value: collapsedCategories)
  }

  @ViewBuilder
  var unlockButton: some View {
    if UserInterfaceIdiom.current == .phone {
      Button(action: { paywall.isShowingModal = true }) {
        Text(paywall.status.tryOrUnlock).bold()
      }
      .if(paywall.status.shouldUseProminent) { $0.buttonStyle(.borderedProminent) }
    } else {
      Button(action: { paywall.isShowingModal = true }) {
        Image(systemName: "sparkles.2")
          .foregroundColor(.accentColor)
      }
    }
  }

  @ToolbarContentBuilder
  var toolbar: some ToolbarContent {
    ToolbarItem(placement: .navigationBarLeading) { UserMenuView() }
    NotificationToolbarItem(placement: .navigationBarLeading, show: .fromUserMenu)

    if !paywall.status.isPaid {
      ToolbarItem(placement: .navigationBarTrailing) { unlockButton }
      MaybeToolbarSpacer(.fixed, placement: .navigationBarTrailing)
    }
    ToolbarItem(placement: .navigationBarTrailing) { filter }

    if UserInterfaceIdiom.current == .phone {
      MaybeBottomBarSearchToolbarItem()
    }
    if schemes.canTryNavigateToPasteboardURL {
      MaybeToolbarSpacer(placement: .bottomBar)
      ToolbarItem(placement: .bottomBar) {
        Button(action: schemes.navigateToPasteboardURL) {
          HStack {
            Image(systemName: "arrow.right.page.on.clipboard")
            Text("Navigate")
          }
        }
        .buttonStyle(.borderedProminent)
      }
    }
  }

  var title: String {
    if paywall.status.isPaid, prefs.showPlusInTitle {
      "MNGA 𝐏𝐥𝐮𝐬"
    } else if paywall.isUnlocked {
      "MNGA"
    } else {
      "MNGA Lite"
    }
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
    .refreshable { await loadData() }
    .navigationTitle(title)
    .navigationBarTitleDisplayMode(.large)
    .listStyle(.sidebar) // collapsible
    .toolbar { toolbar }
  }

  func loadData() async {
    let res: Result<ForumListResponse, LogicError> = await logicCallAsync(.forumList(.with { _ in }))
    if case let .success(response) = res {
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
