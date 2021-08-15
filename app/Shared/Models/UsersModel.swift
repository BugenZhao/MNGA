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
  
  @Published private var users = [String: User?]()

  func localUser(id: String) -> User? {
    if self.users[id] == nil {
      let localResponse: LocalUserResponse? =
        try? logicCall(.localUser(.with { $0.userID = id }))
      self.users[id] = localResponse?.user
    }
    return self.users[id] ?? nil
  }
}
