//
//  FavoriteForumsStorage.swift
//  NGA
//
//  Created by Bugen Zhao on 7/1/21.
//

import Foundation
import SwiftUI

@MainActor
protocol FavoriteForumsStorageProtocol {
  nonisolated init()
  var favoriteForums: [Forum] { get }

  mutating func sync() async
  mutating func remove(id: ForumId) async
  mutating func add(forum: Forum) async
  mutating func move(fromOffsets source: IndexSet, toOffset destination: Int)
}

final class LocalFavoriteForumsStorage: FavoriteForumsStorageProtocol {
  func sync() {
    if !oldFavoriteForums.isEmpty, favoriteForums.isEmpty {
      favoriteForums = oldFavoriteForums
      oldFavoriteForums.removeAll()
    }
  }

  private static let groupStore = UserDefaults(suiteName: Constants.Key.groupStore)!

  @AppStorage("favoriteForums") private var oldFavoriteForums = [Forum]()
  @AppStorage(Constants.Key.favoriteForums, store: groupStore) var favoriteForums = [Forum]()

  func remove(id: ForumId) {
    favoriteForums.removeAll(where: { $0.id == id })
  }

  func add(forum: Forum) {
    if !favoriteForums.contains(where: { $0.id == forum.id }) {
      favoriteForums.append(forum)
    }
  }

  func move(fromOffsets source: IndexSet, toOffset destination: Int) {
    favoriteForums.move(fromOffsets: source, toOffset: destination)
  }
}

final class RemoteFavoriteForumsStorage: FavoriteForumsStorageProtocol {
  @AppStorage("remoteFavoriteForums") var favoriteForums = [Forum]()

  func sync() async {
    let response: Result<FavoriteForumListResponse, LogicError> = await logicCallAsync(.favoriteForumList(.init()))
    if case let .success(r) = response {
      // We don't simply overwrite but merge the changes to preserve the local ordering.
      // 1. Remove forums that are no longer favorite
      favoriteForums.removeAll { !r.forums.contains($0) }
      // 2. Add new forums
      for forum in r.forums {
        if !favoriteForums.contains(where: { $0.id == forum.id }) {
          favoriteForums.append(forum)
        }
      }
    }
  }

  func remove(id: ForumId) async {
    // Local remove first
    favoriteForums.removeAll(where: { $0.id == id })

    let request = FavoriteForumModifyRequest.with {
      $0.operation = .del
      $0.id = id
    }
    let _: Result<FavoriteForumModifyResponse, LogicError> = await logicCallAsync(.favoriteForumModify(request))
    await sync()
  }

  func add(forum: Forum) async {
    // Local add first
    if !favoriteForums.contains(where: { $0.id == forum.id }) {
      favoriteForums.append(forum)
    }

    let request = FavoriteForumModifyRequest.with {
      $0.operation = .add
      $0.id = forum.id
    }
    let _: Result<FavoriteForumModifyResponse, LogicError> = await logicCallAsync(.favoriteForumModify(request))
    await sync()
  }

  func move(fromOffsets source: IndexSet, toOffset destination: Int) {
    // Only local move
    favoriteForums.move(fromOffsets: source, toOffset: destination)
  }
}

class FavoriteForumsStorage: ObservableObject {
  @AppStorage("useRemoteFavoriteForums") var useRemoteFavoriteForums = false

  @Published private var local: LocalFavoriteForumsStorage = .init()
  @Published private var remote: RemoteFavoriteForumsStorage = .init()
  @Published var synced = false

  private var inner: any FavoriteForumsStorageProtocol {
    get { useRemoteFavoriteForums ? remote : local }
    set {
      if useRemoteFavoriteForums {
        if let newRemote = newValue as? RemoteFavoriteForumsStorage {
          remote = newRemote
        }
      } else {
        if let newLocal = newValue as? LocalFavoriteForumsStorage {
          local = newLocal
        }
      }
    }
  }

  @MainActor
  func sync() async {
    logger.info("syncing favorite forums")
    await inner.sync()
    withAnimation { synced = true }
  }

  @MainActor
  func initialSync() async {
    if synced { return }
    await sync()
  }

  @MainActor
  var favoriteForums: [Forum] {
    inner.favoriteForums
  }

  static let shared = FavoriteForumsStorage()

  enum FilterMode: String, CaseIterable {
    case favoritesOnly = "Favorites Only"
    case all = "All Forums"

    var icon: String {
      switch self {
      case .favoritesOnly:
        "star.fill"
      case .all:
        "star.lefthalf.fill"
      }
    }
  }

  @AppStorage("showAll") var filterMode = FilterMode.all

  @MainActor
  func isFavorite(id: ForumId) -> Bool {
    favoriteForums.contains { $0.id == id }
  }

  func toggle(forum: Forum) {
    Task { @MainActor in
      if isFavorite(id: forum.id) {
        await inner.remove(id: forum.id)
      } else {
        await inner.add(forum: forum)
        HapticUtils.play(type: .success)
      }
    }
  }

  func remove(atOffsets offsets: IndexSet) {
    Task { @MainActor in
      let ids = offsets.map { favoriteForums[$0].id }
      for id in ids {
        await inner.remove(id: id)
      }
    }
  }

  @MainActor
  func move(fromOffsets source: IndexSet, toOffset destination: Int) {
    inner.move(fromOffsets: source, toOffset: destination)
  }
}
