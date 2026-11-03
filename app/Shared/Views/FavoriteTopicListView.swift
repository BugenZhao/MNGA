//
//  FavoriteTopicListView.swift
//  NGA
//
//  Created by Bugen Zhao on 7/14/21.
//

import Foundation
import SwiftUI

class FavoriteFolderModel: ObservableObject {
  static let shared = FavoriteFolderModel()

  @Published var allFolders: [FavoriteTopicFolder] = []
  // Whether `allFolders` came from the server. A new account has no folder at all, so an empty list
  // does not mean the folders are still loading.
  @Published var loaded = false
  // Set when the folders failed to load and nothing has been loaded since.
  @Published var loadError: LogicError? = nil

  // Default folder should be the first one.
  var sortedFolders: [FavoriteTopicFolder] {
    allFolders.sorted { $0.isDefault && !$1.isDefault }
  }

  var defaultFolder: FavoriteTopicFolder? {
    allFolders.first { $0.isDefault } ?? allFolders.first
  }

  @MainActor
  func load(force: Bool = false) async {
    if !loaded || force {
      loadError = nil
      let response: Result<FavoriteFolderListResponse, LogicError> = await logicCallAsync(.favoriteFolderList(.init()))
      switch response {
      case let .success(r):
        logger.debug("loaded \(r.folders.count) favorite folders")
        withAnimation {
          allFolders = r.folders
          loaded = true
        }
      case let .failure(e):
        // Keep showing the folders loaded before, if any.
        if !loaded { withAnimation { loadError = e } }
      }
    }
  }

  @MainActor
  func reload() async {
    await load(force: true)
  }

  @MainActor
  func reset() {
    logger.debug("resetting favorite folders")
    allFolders = []
    loaded = false
    loadError = nil
  }

  @MainActor
  func modify(_ request: FavoriteFolderModifyRequest) async {
    let res: Result<FavoriteFolderModifyResponse, LogicError> = await logicCallAsync(.favoriteFolderModify(request))
    if case .success = res {
      HapticUtils.play(type: .success)
      await reload()
    }
  }

  @MainActor
  func create(name: String, haptic: Bool = true) async -> String? {
    let res: Result<FavoriteFolderCreateResponse, LogicError> = await logicCallAsync(.favoriteFolderCreate(.with {
      $0.name = name
      $0.setDefault = false
    }))
    if case let .success(r) = res {
      if haptic { HapticUtils.play(type: .success) }
      await reload()
      return r.folderID
    } else {
      return nil
    }
  }
}

struct FavoriteTopicListInnerView: View {
  typealias DataSource = PagingDataSource<FavoriteTopicListResponse, Topic>

  let folderID: String

  @StateObject var dataSource: DataSource

  static func build(folderID: String) -> Self {
    let dataSource = DataSource(
      buildRequest: { page in
        .favoriteTopicList(.with {
          $0.folderID = folderID
          $0.page = UInt32(page)
        })
      },
      onResponse: { response in
        let items = response.topics
        let pages = response.pages
        return (items, Int(pages))
      },
      id: \.id,
    )

    return Self(folderID: folderID, dataSource: dataSource)
  }

  var body: some View {
    Group {
      if dataSource.notLoaded {
        ProgressView()
          .onAppear { dataSource.initialLoad() }
      } else if dataSource.items.isEmpty {
        ContentUnavailableView("No Favorites", systemImage: "bookmark")
      } else {
        List {
          SafeForEach($dataSource.items, id: \.id) { topic in
            TopicRowLinkView(topic: topic, dimmedSubject: false, showIndicators: false)
              .onAppear { dataSource.loadMoreIfNeeded(currentItem: topic.w) }
          }
          .onDelete { indexSet in deleteFavorites(at: indexSet) }
        }
      }
    }
    .refreshable(dataSource: dataSource)
    .mayGroupedListStyle()
  }

  func deleteFavorites(at indexSet: IndexSet) {
    guard let firstIndex = indexSet.first else { return }
    let topic = dataSource.items[firstIndex] // FIXME: only first

    logicCallAsync(.topicFavor(.with {
      $0.folderID = folderID
      $0.topicID = topic.id
      $0.operation = .delete
    })) { (response: TopicFavorResponse) in
      if !response.isFavored { dataSource.items.remove(at: firstIndex) }
    }
  }
}

struct FavoriteTopicListView: View {
  @State var selectedFolderID: String? = nil
  // Whether the folders have been refreshed since this view appeared.
  @State var refreshed = false
  @StateObject var folders = FavoriteFolderModel.shared

  // Derived from the shared model rather than copied, so that a folder created elsewhere, such as
  // the first favorite of a new account while this view is still in the navigation stack, shows up.
  var currentFolder: FavoriteTopicFolder? {
    guard refreshed else { return nil }
    return folders.allFolders.first { $0.id == selectedFolderID } ?? folders.defaultFolder
  }

  // A new account has no folder until it adds its first favorite.
  var hasNoFolder: Bool {
    refreshed && folders.loaded && folders.allFolders.isEmpty
  }

  var loadError: LogicError? {
    refreshed ? folders.loadError : nil
  }

  var isLoadingFolders: Bool {
    currentFolder == nil && !hasNoFolder && loadError == nil
  }

  // Every time we navigate into this view, refresh the folders.
  func loadFolders() async {
    guard !refreshed else { return }
    await folders.reload()
    withAnimation { refreshed = true }
  }

  func retryLoadingFolders() async {
    refreshed = false
    await loadFolders()
  }

  func modifyCurrentFolder(_ request: FavoriteFolderModifyRequest) {
    guard let currentFolder else { return }

    var request = request
    request.folderID = currentFolder.id

    Task { await folders.modify(request) }
  }

  @State var showingRenameAlert = false
  @State var newName = ""
  @State var showingDeleteConfirmation = false

  @ViewBuilder
  var folderSwitcher: some View {
    // Use toggle instead of picker so that we can display description text.
    ForEach(folders.sortedFolders, id: \.id) { folder in
      Toggle(isOn:
        Binding(
          get: { currentFolder?.id == folder.id },
          set: { _ in withPlusCheck(.multiFavorite) { selectedFolderID = folder.id } },
        )) {
          Text(folder.name)
          if folder.isDefault {
            Text("Default Folder")
          }
        }
        .menuActionDismissBehavior(.disabled)
    }
  }

  @ViewBuilder
  var folderMenu: some View {
    if let currentFolder {
      Menu {
        ControlGroup {
          if currentFolder.isDefault {
            Label("Default", systemImage: "checkmark")
          } else {
            Button(action: { modifyCurrentFolder(.with { $0.setDefault = true }) }) {
              Label("Make Default", systemImage: "folder.fill")
            }
          }
          Button(action: { showingRenameAlert = true; newName = currentFolder.name }) {
            Label("Rename", systemImage: "pencil")
          }
          Button(role: .destructive, action: { showingDeleteConfirmation = true }) {
            Label("Delete", systemImage: "trash")
          }
        } label: {
          Text("#\(currentFolder.id) \(currentFolder.name)")
        }

        folderSwitcher
      } label: {
        Label("Folder", systemImage: currentFolder.isDefault ? "folder.fill" : "folder")
      }

      .alert("Rename Folder", isPresented: $showingRenameAlert) {
        TextField("Folder Name", text: $newName)
        Button("Done", role: .maybeConfirm) {
          modifyCurrentFolder(.with { $0.rename = newName })
        }
        Button("Cancel", role: .cancel) { showingRenameAlert = false }
      }
      .confirmationDialog(
        "Delete the folder and all its topics?",
        isPresented: $showingDeleteConfirmation,
        titleVisibility: .visible,
      ) {
        Button("Delete", role: .destructive) {
          modifyCurrentFolder(.with { $0.delete = true })
        }
      }
    } else if isLoadingFolders {
      ProgressView()
    }
  }

  var body: some View {
    Group {
      if let currentFolder {
        FavoriteTopicListInnerView.build(folderID: currentFolder.id)
          .id(currentFolder.id)
      } else if hasNoFolder {
        ContentUnavailableView(
          "No Favorites",
          systemImage: "bookmark",
          description: Text("Topics you add to favorites will appear here."),
        )
      } else if let error = loadError {
        ContentUnavailableView {
          Label("Failed to Load Folders", systemImage: "exclamationmark.triangle")
        } description: {
          Text(error.error)
        } actions: {
          Button("Retry") { Task { await retryLoadingFolders() } }
        }
      } else {
        ProgressView()
      }
    }
    .task { await loadFolders() }
    .navigationTitle("Favorite Topics")
    .maybeNavigationSubtitle(currentFolder?.name ?? "")
    .toolbar { ToolbarItem(placement: .navigationBarTrailing) { folderMenu } }
  }
}
