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

extension User {
  static let anonymousExample = Self.with {
    $0.name.normal = "??????"
    $0.name.anonymous = "??????"
  }
}

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

  init(id: String, nameHint: String? = nil, style: Style) {
    var user = UsersModel.shared.localUser(id: id)
    if let nameHint = nameHint, user == nil {
      user = .with {
        $0.id = id
        $0.name.normal = nameHint
      }
    }
    self.user = user
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
    let placeholder = Image(systemName: isAnonymous ? "theatermasks.circle.fill" : "person.crop.circle.fill")
      .resizable()

    WebOrAsyncImage(url: pref.showAvatar ? avatarURL : nil, placeholder: placeholder)
  }

  @ViewBuilder
  var avatar: some View {
    Group {
      if style == .huge {
        Button(action: { if let url = avatarURL { viewingImage.show(url: url) } }) {
          avatarInner
        } .buttonStyle(PlainButtonStyle())
      } else if let user = self.user, let action = self.action {
        Button(action: { action.showUserProfile = user }) {
          avatarInner
        } .buttonStyle(PlainButtonStyle())
      } else {
        avatarInner
      }
    } .clipShape(Circle())
      .frame(width: avatarSize, height: avatarSize)
      .foregroundColor(.accentColor)
  }

  var name: String {
    if let name = user?.name, !name.display.isEmpty {
      return name.display
    } else if !id.isEmpty {
      return id
    } else {
      return "????????"
    }
  }

  var idDisplay: String {
    if self.isAnonymous, let user = user {
      return user.name.normal
    } else {
      return id
    }
  }

  var isAnonymous: Bool {
    user?.isAnonymous ?? false
  }

  var shouldRedactName: Bool {
    user == nil || user == User.init() || user == .anonymousExample
  }

  var shouldRedactInfo: Bool {
    shouldRedactName || isAnonymous
  }
  
  var showDetails: Bool {
    style == .huge || (style == .normal && pref.postRowShowUserDetails)
  }
  var showRegDate: Bool {
    style == .huge || (style == .normal && pref.postRowShowUserRegDate)
  }
  
  var nameFont: Font {
    switch style {
    case .compact:
      return .subheadline
    case .normal:
      return showDetails ? .subheadline : .callout
    case .huge:
      return .title
    }
  }

  var body: some View {
    HStack {
      avatar

      VStack(alignment: .leading, spacing: style == .huge ? 4 : 2) {
        HStack {
          Group {
            if showId {
              Text(self.idDisplay)
            } else {
              Text(self.name)
            }
          } .font(nameFont, weight: style == .huge ? .bold : .medium)

          if user?.mute == true {
            Image(systemName: "mic.slash.fill")
              .font(style == .huge ? .body : .footnote)
              .foregroundColor(.red)
          }
        } .onTapGesture { withAnimation { self.showId.toggle() } }
          .redacted(if: shouldRedactName)

        if showDetails {
          HStack(spacing: 6) {
            HStack(spacing: 2) {
              Image(systemName: "text.bubble")
              Text("\(user?.postNum ?? 0)")
                .redacted(if: shouldRedactInfo)
            } .foregroundColor((1..<50 ~= user?.postNum ?? 50) ? .red : .secondary)

            HStack(spacing: 2) {
              Image(systemName: "flag")
              Text(String(format: "%.01f", Double(user?.fame ?? 0) / 10.0))
                .redacted(if: shouldRedactInfo)
            } .foregroundColor((user?.fame ?? 0 < 0) ? .red : .secondary)

            if showRegDate {
              HStack(spacing: 2) {
                Image(systemName: "calendar")
                Text(Date(timeIntervalSince1970: TimeInterval(user?.regDate ?? 0)), style: .date)
                  .redacted(if: shouldRedactInfo)
              }
            }
          } .font(.footnote)
            .foregroundColor(.secondary)
        }
      }
    }
  }
}
