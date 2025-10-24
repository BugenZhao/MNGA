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
  @State var allFolders: [FavoriteTopicFolder] = []

  func reloadFolders() async {
    let response: Result<FavoriteFolderListResponse, LogicError> = await logicCallAsync(.favoriteFolderList(.init()))
    if case let .success(r) = response {
      withAnimation {
        allFolders = r.folders
        currentFolder = r.folders.first { $0.id == currentFolder?.id }
          ?? r.folders.first(where: { $0.isDefault })
      }
    }
  }

  func loadFolders() async {
    if allFolders.isEmpty, currentFolder == nil { await reloadFolders() }
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

        Picker(selection: $currentFolder.withPlusCheck(.multiFavorite).animation()) {
          ForEach(allFolders, id: \.id) { folder in
            Text(folder.name).tag(folder as FavoriteTopicFolder?)
          }
        } label: {
          Text("All Folders")
        }

      } label: {
        Label("Folder", systemImage: currentFolder.isDefault ? "folder.fill" : "folder")
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
    .navigationSubtitle(currentFolder?.name ?? "Default Folder".localized)
    .toolbar { ToolbarItem(placement: .navigationBarTrailing) { folderMenu } }
  }
}
