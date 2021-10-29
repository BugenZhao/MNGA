//
//  UserView.swift
//  UserView
//
//  Created by Bugen Zhao on 2021/9/11.
//

import Foundation
import SwiftUI
import SDWebImageSwiftUI
import SwiftUIX

struct UserView: View {
  enum Style {
    case compact
    case normal
    case huge
  }

  @State var showId = false
  @StateObject var pref = PreferencesStorage.shared

  @OptionalEnvironmentObject<TopicDetailsActionModel> var action
  @EnvironmentObject var viewingImage: ViewingImageModel

  let user: User?
  let id: String
  let style: Style

  init(id: String, style: Style) {
    self.user = UsersModel.shared.localUser(id: id)
    self.id = id
    self.style = style
  }

  init(user: User, style: Style) {
    self.user = user
    self.id = user.id
    self.style = style
  }


  private var avatarSize: CGFloat {
    switch style {
    case .compact:
      return 24
    case .normal:
      return 36
    case .huge:
      return 54
    }
  }

  private var avatarURL: URL? {
    URL(string: user?.avatarURL ?? "")
  }

  @ViewBuilder
  var avatarInner: some View {
    let placeholder = Image(systemName: "person.circle.fill")
      .resizable()

    WebOrAsyncImage(url: pref.showAvatar ? avatarURL : nil, placeholder: placeholder)
  }

  @ViewBuilder
  var avatar: some View {
    if style == .huge, let url = avatarURL {
      Button(action: { viewingImage.show(url: url) }) {
        avatarInner
      } .buttonStyle(PlainButtonStyle())
    } else if let user = self.user, let action = self.action {
      Button(action: { action.showUserProfile = user }) {
        avatarInner
      } .buttonStyle(PlainButtonStyle())
    } else {
      avatarInner
    }
  }

  var name: String {
    if let name = user?.name, !name.isEmpty {
      return name
    } else if !id.isEmpty {
      return id
    } else {
      return "????????"
    }
  }

  var badUser: Bool {
    user == nil || user == User.init()
  }

  var body: some View {
    HStack {
      avatar
        .foregroundColor(.accentColor)
        .frame(width: avatarSize, height: avatarSize)
        .clipShape(Circle())

      VStack(alignment: .leading, spacing: style == .huge ? 4 : 2) {
        Group {
          if showId {
            Text(id)
          } else {
            Text(self.name)
          }
        } .font(style == .huge ? .title : .subheadline, weight: style == .huge ? .bold : .medium)
          .onTapGesture { withAnimation { self.showId.toggle() } }
          .redacted(if: badUser)

        if style != .compact {
          HStack(spacing: 6) {
            HStack(spacing: 2) {
              Image(systemName: "text.bubble")
              Text("\(user?.postNum ?? 0)")
                .redacted(if: badUser)
            } .foregroundColor((1..<50 ~= user?.postNum ?? 50) ? .red : .secondary)

            HStack(spacing: 2) {
              Image(systemName: "flag")
              Text(String(format: "%.01f", Double(user?.fame ?? 0) / 10.0))
                .redacted(if: badUser)
            } .foregroundColor((user?.fame ?? 0 < 0) ? .red : .secondary)

            if style == .huge {
              HStack(spacing: 2) {
                Image(systemName: "calendar")
                Text(Date(timeIntervalSince1970: TimeInterval(user?.regDate ?? 0)), style: .date)
                  .redacted(if: badUser)
              }
            }
          } .font(.footnote)
            .foregroundColor(.secondary)
        }
      }
    }
  }
}
