//
//  PostRowUserView.swift
//  PostRowUserView
//
//  Created by Bugen Zhao on 7/18/21.
//

import Foundation
import SwiftUI
import SDWebImageSwiftUI

struct PostRowUserView: View, Equatable {
  @StateObject var pref = PreferencesStorage.shared

  static func == (lhs: PostRowUserView, rhs: PostRowUserView) -> Bool {
    return lhs.post.id == rhs.post.id
  }

  let post: Post
  let user: User?
  let compact: Bool

  private var avatarSize: CGFloat {
    compact ? 24 : 36
  }

  static func build(post: Post, user: User? = nil, compact: Bool = false) -> Self {
    var user = user
    if user == nil {
      user = try? (logicCall(.localUser(.with { $0.userID = post.authorID })) as LocalUserResponse).user
    }
    return Self.init(post: post, user: user, compact: compact)
  }

  @State var showId = false

  @ViewBuilder
  func buildAvatar(user: User?) -> some View {
    let placeholder = Image(systemName: "person.circle.fill")
      .resizable()

    if pref.showAvatar, let url = URL(string: user?.avatarURL ?? "") {
      WebImage(url: url)
        .resizable()
        .placeholder(placeholder)
    } else {
      placeholder
    }
  }

  var body: some View {
    HStack {
      buildAvatar(user: user)
        .foregroundColor(.accentColor)
        .frame(width: avatarSize, height: avatarSize)
        .clipShape(Circle())

      VStack(alignment: .leading, spacing: 2) {
        Group {
          if showId {
            Text(post.authorID)
          } else {
            Text(user?.name ?? post.authorID)
          }
        } .font(.subheadline)
          .onTapGesture { withAnimation { self.showId.toggle() } }

        if !compact {
          HStack(spacing: 6) {

            HStack(spacing: 2) {
              Image(systemName: "text.bubble")
              Text("\(user?.postNum ?? 0)")
            } .foregroundColor((user?.postNum ?? 50 < 50) ? .red : .secondary)
            HStack(spacing: 2) {
              Image(systemName: "calendar")
              Text(Date(timeIntervalSince1970: TimeInterval(user?.regDate ?? 0)), style: .date)
            }
            HStack(spacing: 2) {
              Image(systemName: "flag")
              Text("\(user?.fame ?? 0)")
            } .foregroundColor((user?.fame ?? 0 < 0) ? .red : .secondary)

          } .font(.footnote)
            .foregroundColor(.secondary)
        }
      } .redacted(reason: user == nil ? .placeholder : [])
    }
  }
}
