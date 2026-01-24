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

  @Published var allFolders = [FavoriteTopicFolder]()

  // Default folder should be the first one.
  var sortedFolders: [FavoriteTopicFolder] {
    allFolders.sorted { $0.isDefault && !$1.isDefault }
  }

  @MainActor
  func load(force: Bool = false) async {
    if allFolders.isEmpty || force {
      let response: Result<FavoriteFolderListResponse, LogicError> = await logicCallAsync(.favoriteFolderList(.init()))
      if case let .success(r) = response {
        logger.debug("loaded \(r.folders.count) favorite folders")
        withAnimation { allFolders = r.folders }
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
  @State var currentFolder: FavoriteTopicFolder? = nil
  @StateObject var folders = FavoriteFolderModel.shared

  func refreshCurrent() {
    withAnimation {
      currentFolder = folders.allFolders.first { $0.id == currentFolder?.id }
        ?? folders.allFolders.first(where: { $0.isDefault })
    }
  }

  // Every time we navigate into this view, refresh the folders.
  func loadFolders() async {
    if currentFolder == nil {
      await folders.reload()
      refreshCurrent()
    }
  }

  func modifyCurrentFolder(_ request: FavoriteFolderModifyRequest) {
    guard let currentFolder else { return }

    var request = request
    request.folderID = currentFolder.id

    Task {
      await folders.modify(request)
      refreshCurrent()
    }
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
          set: { _ in withPlusCheck(.multiFavorite) { currentFolder = folder } },
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
    } else {
      ProgressView()
    }
  }

  var body: some View {
    Group {
      if let currentFolder {
        FavoriteTopicListInnerView.build(folderID: currentFolder.id)
          .id(currentFolder.id)
      } else {
        ProgressView()
          .task { await loadFolders() }
      }
    }
    .navigationTitle("Favorite Topics")
    .maybeNavigationSubtitle(currentFolder?.name ?? "Default Folder".localized)
    .toolbar { ToolbarItem(placement: .navigationBarTrailing) { folderMenu } }
  }
}
