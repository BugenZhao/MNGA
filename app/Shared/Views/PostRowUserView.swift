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
    return lhs.post.id == rhs.post.id
  }

  let post: Post
  let compact: Bool

  init(post: Post, compact: Bool = false) {
    self.post = post
    self.compact = compact
  }

  private var user: User? {
    self.users.localUser(id: self.post.authorID)
  }
  
  private var style: UserView.Style {
    self.compact ? .compact : .normal
  }

  var body: some View {
    if let user = self.user {
      UserView(user: user, style: style)
    } else {
      UserView(id: post.authorID, style: style)
    }
  }
}
