//
//  FavoriteForumsStorage.swift
//  NGA
//
//  Created by Bugen Zhao on 7/1/21.
//

import Foundation
import SwiftUI

protocol FavoriteForumsStorageProtocol {
  var favoriteForums: [Forum] { get }
  mutating func initialLoad() async
  mutating func remove(id: ForumId) async
  mutating func add(forum: Forum) async
}

struct LocalFavoriteForumsStorage: FavoriteForumsStorageProtocol {
  init() {
    if !oldFavoriteForums.isEmpty, favoriteForums.isEmpty {
      favoriteForums = oldFavoriteForums
      oldFavoriteForums.removeAll()
    }
  }

  func initialLoad() async {}

  private static let groupStore = UserDefaults(suiteName: Constants.Key.groupStore)!

  @AppStorage("favoriteForums") private var oldFavoriteForums = [Forum]()
  @AppStorage(Constants.Key.favoriteForums, store: groupStore) var favoriteForums = [Forum]()

  func remove(id: ForumId) async {
    if let index = favoriteForums.firstIndex(where: { $0.id == id }) {
      favoriteForums.remove(at: index)
    }
  }

  func add(forum: Forum) async {
    if !favoriteForums.contains(where: { $0.id == forum.id }) {
      favoriteForums.append(forum)
    }
  }
}

class FavoriteForumsStorage: ObservableObject {
  @Published var inner: any FavoriteForumsStorageProtocol

  init() {
    inner = LocalFavoriteForumsStorage()
  }

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

  func isFavorite(id: ForumId) -> Bool {
    favoriteForums.contains { $0.id == id }
  }

  func toggle(forum: Forum) {
    Task {
      if isFavorite(id: forum.id) {
        await inner.remove(id: forum.id)
      } else {
        await inner.add(forum: forum)
        HapticUtils.play(type: .success)
      }
    }
  }

  func remove(atOffsets offsets: IndexSet) {
    let ids = offsets.map { favoriteForums[$0].id }
    Task {
      for id in ids {
        await inner.remove(id: id)
      }
    }
  }
}
