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

  @State var searchText = ""
  @State var isSearching = false

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

  var notLoaded: Bool {
    allFolders.isEmpty && currentFolder == nil
  }

  func loadFolders() async {
    if notLoaded {
      let response: Result<FavoriteFolderListResponse, LogicError> = await logicCallAsync(.favoriteFolderList(.init()))
      if case let .success(r) = response {
        withAnimation {
          allFolders = r.folders
          currentFolder = r.folders.first(where: { $0.isDefault })
        }
      }
    }
  }

  var currentFolderID: String {
    if let currentFolder, !currentFolder.isDefault {
      currentFolder.id
    } else {
      "1"
    }
  }

  var currentIsDefault: Bool {
    currentFolderID == "1"
  }

  @ViewBuilder
  var folderMenu: some View {
    if notLoaded {
      ProgressView()
    } else {
      Menu {
        Section("All Folders") {
          Picker(selection: $currentFolder.animation(), label: Text("Folder")) {
            ForEach(allFolders, id: \.id) { folder in
              Text(folder.name).tag(folder as FavoriteTopicFolder?)
            }
          }
        }
      } label: {
        Label("Folder", systemImage: currentIsDefault ? "folder.fill" : "folder")
      }
    }
  }

  var body: some View {
    FavoriteTopicListInnerView.build(folderID: currentFolderID)
      .id(currentFolderID)
      .navigationTitle("Favorite Topics")
      .navigationSubtitle(currentFolder?.name ?? "Default Folder".localized)
      .toolbar { ToolbarItem(placement: .navigationBarTrailing) { folderMenu } }
      .task { await loadFolders() }
  }
}
