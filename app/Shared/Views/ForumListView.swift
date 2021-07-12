//
//  ForumListView.swift
//  NGA
//
//  Created by Bugen Zhao on 6/30/21.
//

import Foundation
import SwiftUI
import SDWebImageSwiftUI
import SwiftUIX

struct UserMenu: View {
  @EnvironmentObject var authStorage: AuthStorage

  @State var user: User? = nil

  let showHistory: Binding<Bool>

  var body: some View {
    let uid = authStorage.authInfo.inner.uid
    let shouldLogin = authStorage.shouldLogin

    Menu {
      Section {
        Button(action: { showHistory.wrappedValue = true }) {
          Label("History", systemImage: "clock")
        }
      }
      Section {
        if !shouldLogin {
          if let user = self.user {
            Menu {
              Label(user.id, systemImage: "number")
              Label {
                Text(Date(timeIntervalSince1970: TimeInterval(user.regDate)), style: .date)
              } icon: {
                Image(systemName: "calendar")
              }
              Label("\(user.postNum) Posts", systemImage: "text.bubble")
            } label: {
              Label(user.name, systemImage: "person.fill")
            }
          } else {
            Label(uid, systemImage: "person.fill")
          }
        }

        if shouldLogin {
          Button(action: { authStorage.clearAuth() }) {
            Label("Sign In", systemImage: "person.crop.circle.badge.plus")
          }
        } else {
          Button(action: { authStorage.clearAuth() }) {
            Label("Sign Out", systemImage: "person.crop.circle.fill.badge.minus")
          }
        }
      }
    } label: {
      let icon = shouldLogin ? "person.crop.circle" : "person.crop.circle.fill"
      Label("Me", systemImage: icon)
    }
      .imageScale(.large)
      .onAppear { loadData() }
      .onChange(of: authStorage.authInfo) { _ in loadData() }
  }

  func loadData() {
    let uid = authStorage.authInfo.inner.uid
    logicCallAsync(.remoteUser(.with { $0.userID = uid })) { (response: RemoteUserResponse) in
      if response.hasUser {
        self.user = response.user
      }
    }
  }
}

struct ForumListView: View {
  @StateObject var favorites = FavoriteForumsStorage()

  @State var categories = [Category]()
  @State var searchText: String = ""
  @State var isSearching: Bool = false
  @State var showHistory: Bool = false

  @ViewBuilder
  func buildLink(_ forum: Forum, inFavoritesSection: Bool = true) -> some View {
    let isFavorite = favorites.isFavorite(id: forum.id)

    NavigationLink(destination: TopicListView(forum: forum)) {
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
          let forums = category.forums.filter {
            searchText.isEmpty || $0.name.contains(searchText)
          }
          if !forums.isEmpty {
            Section(header: Text(category.name).font(.subheadline).fontWeight(.medium)) {
              ForEach(forums, id: \.hashIdentifiable) { forum in
                buildLink(forum)
              }
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
    } .imageScale(.large)
  }

  var body: some View {
    VStack {
      List {
        if searchText.isEmpty && !isSearching {
          favoritesSection
        }
        if favorites.filterMode == .all || isSearching {
          allForumsSection
        }
      }
    } .onAppear { loadData() }
      .navigationTitle("Forums")
    #if os(iOS)
      .navigationSearchBar {
        SearchBar(
          NSLocalizedString("Search Forums", comment: ""),
          text: $searchText,
          isEditing: $isSearching.animation()
        )
      }
    #endif
    .modifier(DoubleItemsToolbarModifier(
      buildLeading: { UserMenu(showHistory: $showHistory) },
      buildTrailing: { filterMenu }
      ))
      .background {
      NavigationLink(destination: TopicHistoryListView(), isActive: $showHistory) { }
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
