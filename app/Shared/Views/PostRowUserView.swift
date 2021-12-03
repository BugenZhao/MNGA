//
//  PostRowUserView.swift
//  PostRowUserView
//
//  Created by Bugen Zhao on 7/18/21.
//

import Foundation
import SwiftUI

struct PostRowUserView: View, Equatable {
  @StateObject var users = UsersModel.shared

  static func == (lhs: PostRowUserView, rhs: PostRowUserView) -> Bool {
    lhs.post.id == rhs.post.id
  }

  let post: Post
  let compact: Bool
  let isAuthor: Bool

  private var user: User? {
    users.localUser(id: post.authorID)
  }

  private var style: UserView.Style {
    compact ? .compact : .normal
  }

  var body: some View {
    if let user = self.user {
      UserView(user: user, style: style, isAuthor: isAuthor)
    } else {
      UserView(id: post.authorID, style: style, isAuthor: isAuthor)
    }
  }
}
