//
//  FavoriteTopicListView.swift
//  NGA
//
//  Created by Bugen Zhao on 7/14/21.
//

import Foundation
import SwiftUI

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
      id: \.id
    )

    return Self(folderID: folderID, dataSource: dataSource)
  }

  var body: some View {
    Group {
      if dataSource.notLoaded {
        ProgressView()
          .onAppear { dataSource.initialLoad() }
      } else {
        List {
          ForEach($dataSource.items, id: \.id) { topic in
            CrossStackNavigationLinkHack(destination: TopicDetailsView.build(topicBinding: topic), id: topic.w.id) {
              TopicRowView(topic: topic.w, dimmedSubject: false, showIndicators: false)
                .onAppear { dataSource.loadMoreIfNeeded(currentItem: topic.w) }
            }
          }.onDelete { indexSet in deleteFavorites(at: indexSet) }
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
      // FIXME: folder id
      $0.topicID = topic.id
      $0.operation = .delete
    })) { (response: TopicFavorResponse) in
      if !response.isFavored { dataSource.items.remove(at: firstIndex) }
    }
  }
}

struct FavoriteTopicListView: View {
  @State var currentFolder: FavoriteTopicFolder? = nil
  // Initially, we don't know the ID of default folder. To avoid reloading the list after initial
  // folder load, we keep using "1" as the default folder ID. After user performs any action, we
  // will reload the folder list and use the real ID.
  @State var forceUseRealID = false
  @State var allFolders: [FavoriteTopicFolder] = []

  func reloadFolders(initial: Bool = false) async {
    let response: Result<FavoriteFolderListResponse, LogicError> = await logicCallAsync(.favoriteFolderList(.init()))
    if case let .success(r) = response {
      withAnimation {
        allFolders = r.folders
        currentFolder = r.folders.first { $0.id == currentFolder?.id }
          ?? r.folders.first(where: { $0.isDefault })
        if !initial {
          forceUseRealID = true
        }
      }
    }
  }

  func loadFolders() async {
    if allFolders.isEmpty, currentFolder == nil { await reloadFolders(initial: true) }
  }

  var currentIsDefault: Bool {
    currentFolder?.isDefault ?? true
  }

  func modifyCurrentFolder(_ request: FavoriteFolderModifyRequest) {
    guard let currentFolder else { return }

    var request = request
    request.folderID = currentFolder.id

    logicCallAsync(.favoriteFolderModify(request)) { (_: FavoriteFolderModifyResponse) in
      HapticUtils.play(type: .success)
      Task { await reloadFolders() }
    }
  }

  @State var showingRenameAlert = false
  @State var newName = ""
  @State var showingDeleteConfirmation = false

  @ViewBuilder
  var folderMenu: some View {
    if let currentFolder {
      Menu {
        Section("#\(currentFolder.id)") {
          Menu {
            Picker(selection: $currentFolder.withPlusCheck(.multiFavorite).animation()) {
              ForEach(allFolders, id: \.id) { folder in
                Text(folder.name).tag(folder as FavoriteTopicFolder?)
              }
            }
          } label: {
            Label("Folders", systemImage: "folder")
            Text(currentFolder.name)
          }
        }

        ControlGroup {
          if currentIsDefault {
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
        }

      } label: {
        Label("Folder", systemImage: currentIsDefault ? "folder.fill" : "folder")
      }

      .alert("Rename Folder", isPresented: $showingRenameAlert) {
        TextField("Folder Name", text: $newName)
        Button("Done", role: .confirm) {
          modifyCurrentFolder(.with { $0.rename = newName })
        }
        Button("Cancel", role: .cancel) { showingRenameAlert = false }
      }
      .confirmationDialog(
        "Delete the folder and all its topics?",
        isPresented: $showingDeleteConfirmation,
        titleVisibility: .visible
      ) {
        Button("Delete", role: .destructive) {
          modifyCurrentFolder(.with { $0.delete = true })
        }
      }
    } else {
      ProgressView()
    }
  }

  var currentFolderNormalizedID: String {
    if let currentFolder, forceUseRealID || !currentFolder.isDefault {
      currentFolder.id
    } else {
      "1"
    }
  }

  var body: some View {
    FavoriteTopicListInnerView.build(folderID: currentFolder?.id ?? "1")
      .id(currentFolderNormalizedID)
      .navigationTitle("Favorite Topics")
      .navigationSubtitle(currentFolder?.name ?? "Default Folder".localized)
      .toolbar { ToolbarItem(placement: .navigationBarTrailing) { folderMenu } }
      .task { await loadFolders() }
  }
}
