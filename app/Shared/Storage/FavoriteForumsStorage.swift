//
//  FavoriteForumsStorage.swift
//  NGA
//
//  Created by Bugen Zhao on 7/1/21.
//

import Foundation
import SwiftUI

class FavoriteForumsStorage: ObservableObject {
  @AppStorage("favoriteForums") var favoriteForums = [Forum]()

  func isFavorite(id: String) -> Bool {
    favoriteForums.firstIndex { $0.id == id } != nil
  }

  func addToFavorites(forum: Forum) {
    if isFavorite(id: forum.id) { return }
    favoriteForums.append(forum)
  }

  func removeFromFavorites(id: String) {
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
