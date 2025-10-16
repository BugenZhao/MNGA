//
//  UserView.swift
//  UserView
//
//  Created by Bugen Zhao on 2021/9/11.
//

import Flow
import Foundation
import SDWebImageSwiftUI
import SwiftUI
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
    case vertical
  }

  @State var showId = false
  @StateObject var pref = PreferencesStorage.shared

  @EnvironmentObject<TopicDetailsActionModel>.Optional var action
  @EnvironmentObject var viewingImage: ViewingImageModel

  @State var user: User?

  let id: String
  let style: Style
  let isAuthor: Bool
  // User loaded separately with `remoteUser` may contain more info like `ipLocation`
  // than the one embedded in post/topic.
  let loadRemote: Bool

  init(id: String, nameHint: String? = nil, style: Style, isAuthor: Bool = false, loadRemote: Bool = false) {
    var user = UsersModel.shared.localUser(id: id)
    if let nameHint, user == nil {
      user = .with {
        $0.id = id
        $0.name.normal = nameHint
      }
    }
    self.user = user
    self.id = id
    self.style = style
    self.isAuthor = isAuthor
    self.loadRemote = loadRemote
  }

  init(user: User, style: Style, isAuthor: Bool = false, loadRemote: Bool = false) {
    self.user = user
    id = user.id
    self.style = style
    self.isAuthor = isAuthor
    self.loadRemote = loadRemote
  }

  private var avatarSize: CGFloat {
    switch style {
    case .compact:
      24
    case .normal:
      36
    case .huge:
      56
    case .vertical:
      48
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
        }.buttonStyle(PlainButtonStyle())
      } else if let user, let action {
        Button(action: { withPlusCheck(.userProfile) { action.showUserProfile = user } }) {
          avatarInner
        }.buttonStyle(PlainButtonStyle())
      } else {
        avatarInner
      }
    }.clipShape(Circle())
      .frame(width: avatarSize, height: avatarSize)
      .foregroundColor(.accentColor)
  }

  var name: String {
    if let name = user?.name, !name.display.isEmpty {
      name.display
    } else if !id.isEmpty {
      id
    } else {
      "????????"
    }
  }

  var idDisplay: String {
    if isAnonymous, let user {
      user.name.normal
    } else {
      id
    }
  }

  var isAnonymous: Bool {
    user?.isAnonymous ?? false
  }

  var shouldRedactName: Bool {
    user == nil || user == User() || user == .anonymousExample
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

  var showIpLocation: Bool {
    style == .huge && user?.ipLocation.isEmpty == false
  }

  var nameFont: Font {
    switch style {
    case .compact:
      .subheadline
    case .normal:
      showDetails ? .subheadline : .callout
    case .huge:
      .title
    case .vertical:
      .footnote
    }
  }

  var nameWeight: Font.Weight {
    if style == .huge {
      .bold
    } else if isAuthor {
      .semibold
    } else {
      .medium
    }
  }

  @ViewBuilder
  var nameView: some View {
    HStack(spacing: 4) {
      Group {
        if showId {
          Text(idDisplay)
        } else {
          Text(name)
        }
      }.font(nameFont, weight: nameWeight)

      if style != .vertical {
        Group {
          if user?.mute == true {
            Image(systemName: "mic.slash.fill")
              .foregroundColor(.red)
          }
          if isAuthor, pref.postRowShowAuthorIndicator {
            Image(systemName: "person.fill")
              .foregroundColor(.accentColor)
          }
        }.font(nameFont)
      }
    }.onTapGesture { withAnimation { showId.toggle() } }
      .redacted(if: shouldRedactName)
  }

  @ViewBuilder
  var vertical: some View {
    VStack {
      avatar
      nameView
        .lineLimit(1)
        .truncationMode(.middle)
        .frame(width: avatarSize * 1.5)
    }
  }

  @ViewBuilder
  var horizontal: some View {
    HStack {
      avatar

      VStack(alignment: .leading, spacing: style == .huge ? 4 : 2) {
        nameView

        if showDetails {
          HFlow(itemSpacing: 6) {
            HStack(spacing: 2) {
              Image(systemName: "text.bubble")
              Text("\(user?.postNum ?? 0)")
                .redacted(if: shouldRedactInfo)
            }.foregroundColor((1 ..< 50 ~= user?.postNum ?? 50) ? .red : .secondary)

            HStack(spacing: 2) {
              Image(systemName: "flag")
              Text(String(format: "%.01f", Double(user?.fame ?? 0) / 10.0))
                .redacted(if: shouldRedactInfo)
            }.foregroundColor((user?.fame ?? 0 < 0) ? .red : .secondary)

            if showRegDate {
              HStack(spacing: 2) {
                Image(systemName: "calendar")
                Text(Date(timeIntervalSince1970: TimeInterval(user?.regDate ?? 0)), style: .date)
                  .redacted(if: shouldRedactInfo)
              }
            }

            if showIpLocation {
              HStack(spacing: 2) {
                Image(systemName: "mappin")
                Text(user?.ipLocation ?? "Unknown".localized)
                  .redacted(if: shouldRedactInfo)
              }
            }
          }

          .font(.footnote)
          .foregroundColor(.secondary)
        }
      }
    }
  }

  var body: some View {
    Group {
      if style == .vertical {
        vertical
      } else {
        horizontal
      }
    }.task {
      if loadRemote, let remoteUser = await UsersModel.shared.remoteUser(id: id) {
        withAnimation { user = remoteUser }
      }
    }
  }
}
