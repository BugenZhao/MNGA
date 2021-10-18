//
//  ShortMessagePostRowView.swift
//  MNGA
//
//  Created by Bugen Zhao on 2021/10/19.
//

import Foundation
import SwiftUI
import SwiftUIX

struct ShortMessagePostRowView: View {
  let post: ShortMessagePost

  @StateObject var pref = PreferencesStorage.shared
  @StateObject var users = UsersModel.shared
  @StateObject var attachments = AttachmentsModel()

  private var user: User? {
    self.users.localUser(id: self.post.authorID)
  }

  @ViewBuilder
  var menuButton: some View {
    #if os(iOS)
      if #available(iOS 15.0, *) {
        Menu(content: { menu }) {
          Image(systemName: "ellipsis.circle.fill")
            .symbolRenderingMode(.hierarchical)
            .imageScale(.large)
        }
      } else {
        Menu(content: { menu }) {
          Image(systemName: "ellipsis")
            .imageScale(.large)
        }
      }
    #endif
  }

  @ViewBuilder
  var header: some View {
    HStack {
      if let user = self.user {
        UserView(user: user, style: .normal)
      } else {
        UserView(id: post.authorID, style: .normal)
      }
      Spacer()
      menuButton
    }
  }

  @ViewBuilder
  var footer: some View {
    HStack {
      Spacer()
      Group {
        DateTimeTextView.build(timestamp: post.postDate)
      } .foregroundColor(.secondary)
        .font(.footnote)
    }
  }

  @ViewBuilder
  var content: some View {
    TopicSubjectContentInnerView(content: post.subject, lineLimit: nil)
    PostContentView(content: post.content)
      .equatable()
  }

  @ViewBuilder
  var menu: some View {
    Section {
      Button(action: { copyToPasteboard(string: post.content.raw) }) {
        Label("Copy Raw Content", systemImage: "doc.on.doc")
      }
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      header
      content
      footer
    } .padding(.vertical, 4)
      .fixedSize(horizontal: false, vertical: true)
    #if os(macOS)
      .contextMenu { menu }
    #endif
  }
}
