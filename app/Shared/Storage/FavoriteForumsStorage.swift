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
}

struct LocalFavoriteForumsStorage: FavoriteForumsStorageProtocol {
  func sync() async {
    if !oldFavoriteForums.isEmpty, favoriteForums.isEmpty {
      favoriteForums = oldFavoriteForums
      oldFavoriteForums.removeAll()
    }
  }

  private static let groupStore = UserDefaults(suiteName: Constants.Key.groupStore)!

  @AppStorage("favoriteForums") private var oldFavoriteForums = [Forum]()
  @AppStorage(Constants.Key.favoriteForums, store: groupStore) var favoriteForums = [Forum]()

  func remove(id: ForumId) async {
    favoriteForums.removeAll(where: { $0.id == id })
  }

  func add(forum: Forum) async {
    if !favoriteForums.contains(where: { $0.id == forum.id }) {
      favoriteForums.append(forum)
    }
  }
}

struct RemoteFavoriteForumsStorage: FavoriteForumsStorageProtocol {
  @AppStorage("remoteFavoriteForums") var favoriteForums = [Forum]()

  mutating func sync() async {
    let response: Result<FavoriteForumListResponse, LogicError> = await logicCallAsync(.favoriteForumList(.init()))
    if case let .success(r) = response {
      favoriteForums = r.forums
    }
  }

  mutating func remove(id: ForumId) async {
    // Local remove first
    favoriteForums.removeAll(where: { $0.id == id })

    let request = FavoriteForumModifyRequest.with {
      $0.operation = .del
      $0.id = id
    }
    let _: Result<FavoriteForumModifyResponse, LogicError> = await logicCallAsync(.favoriteForumModify(request))
    await sync()
  }

  mutating func add(forum: Forum) async {
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
}

class FavoriteForumsStorage: ObservableObject {
  @Published private var inner: any FavoriteForumsStorageProtocol
  private var synced = false

  init() {
    inner = RemoteFavoriteForumsStorage()
  }

  func sync() async {
    await inner.sync()
    synced = true
  }

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
}
