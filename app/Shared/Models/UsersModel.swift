//
//  UsersModel.swift
//  UsersModel
//
//  Created by Bugen Zhao on 8/15/21.
//

import Foundation
import SwiftUI

class UsersModel: ObservableObject {
  static let shared = UsersModel()

  // CAVEATS: should not be @Published here, may lead to bad performance
  private var users = [String: User?]()

  func localUser(id: String) -> User? {
    if self.users[id] == nil {
      let localResponse: LocalUserResponse? =
        try? logicCall(.localUser(.with { $0.userID = id }))
      if let r = localResponse, r.hasUser {
        self.users[id] = r.user
      }
    }
    return self.users[id] ?? nil
  }
  
  func add(user: User) {
    self.users[user.id] = user
  }
}
