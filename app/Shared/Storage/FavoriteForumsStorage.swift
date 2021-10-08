//
//  FavoriteForumsStorage.swift
//  NGA
//
//  Created by Bugen Zhao on 7/1/21.
//

import Foundation
import SwiftUI

class FavoriteForumsStorage: ObservableObject {
  static let shared = FavoriteForumsStorage()

  init() {
    if !oldFavoriteForums.isEmpty && favoriteForums.isEmpty {
      favoriteForums = oldFavoriteForums
      oldFavoriteForums.removeAll()
    }
  }

  static private let groupStore = UserDefaults.init(suiteName: Constants.Key.groupStore)!

  enum FilterMode: String, CaseIterable {
    case favoritesOnly = "Favorites Only"
    case all = "All Forums"

    var icon: String {
      switch self {
      case .favoritesOnly:
        return "star.fill"
      case .all:
        return "star.lefthalf.fill"
      }
    }

    var filterIcon: String {
      switch self {
      case .all:
        return "line.horizontal.3.decrease.circle"
      default:
        return "line.horizontal.3.decrease.circle.fill"
      }
    }
  }

  @AppStorage("favoriteForums") private var oldFavoriteForums = [Forum]()

  @AppStorage(Constants.Key.favoriteForums, store: groupStore) var favoriteForums = [Forum]()
  @AppStorage("showAll") var filterMode = FilterMode.all

  func isFavorite(id: ForumId) -> Bool {
    favoriteForums.firstIndex { $0.id == id } != nil
  }

  func addToFavorites(forum: Forum) {
    if isFavorite(id: forum.id) { return }
    favoriteForums.append(forum)
  }

  func removeFromFavorites(id: ForumId) {
    if let index = favoriteForums.firstIndex(where: { $0.id == id }) {
      favoriteForums.remove(at: index)
    }
  }

  func toggleFavorite(forum: Forum) {
    if let index = favoriteForums.firstIndex(where: { $0.id == forum.id }) {
      favoriteForums.remove(at: index)
    } else {
      favoriteForums.append(forum)
    }
  }
}
