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

  init() {
    add(user: User.dummy)
  }

  func localUser(id: String) -> User? {
    if users[id] == nil {
      let localResponse: LocalUserResponse? =
        try? logicCall(.localUser(.with { $0.userID = id }))
      if let r = localResponse, r.hasUser {
        add(user: r.user)
      }
    }
    return users[id] ?? nil
  }

  func remoteUser(id: String, showError: Bool = true) async -> User? {
    if users[id]??.remote != true {
      return await remoteUser(.with { $0.userID = id }, showError: showError)
    }
    return users[id] ?? nil
  }

  func remoteUser(_ req: RemoteUserRequest, showError: Bool = true) async -> User? {
    let errorToastModel: ToastModel? = showError ? .banner : nil
    let res: Result<RemoteUserResponse, LogicError> = await logicCallAsync(.remoteUser(req), errorToastModel: errorToastModel)
    if case let .success(r) = res, r.hasUser {
      add(user: r.user)
      return r.user
    }
    return nil
  }

  func add(user: User) {
    users[user.id] = user
  }
}
