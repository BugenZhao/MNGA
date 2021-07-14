//
//  UserMenuView.swift
//  NGA
//
//  Created by Bugen Zhao on 7/14/21.
//

import Foundation
import SwiftUI
import SDWebImageSwiftUI

struct UserMenuView: View {
  @EnvironmentObject var authStorage: AuthStorage

  @State var user: User? = nil

  @State var showHistory: Bool = false
  @State var showFavorite: Bool = false

  @ViewBuilder
  var navigationBackgrounds: some View {
    NavigationLink(destination: TopicHistoryListView.build(), isActive: $showHistory) { }
    NavigationLink(destination: FavoriteTopicListView.build(), isActive: $showFavorite) { }
  }

  var body: some View {
    let uid = authStorage.authInfo.inner.uid
    let shouldLogin = authStorage.shouldLogin

    Menu {
      Section {
        Button(action: { showFavorite = true }) {
          Label("Favorite Topics", systemImage: "heart.fill")
        }
        Button(action: { showHistory = true }) {
          Label("History", systemImage: "clock")
        }
      }
      Section {
        if !shouldLogin {
          if let user = self.user {
            Menu {
              Label(user.id, systemImage: "number")
              Label {
                Text(Date(timeIntervalSince1970: TimeInterval(user.regDate)), style: .date)
              } icon: {
                Image(systemName: "calendar")
              }
              Label("\(user.postNum) Posts", systemImage: "text.bubble")
            } label: {
              Label(user.name, systemImage: "person.fill")
            }
          } else {
            Label(uid, systemImage: "person.fill")
          }
        }

        if shouldLogin {
          Button(action: { authStorage.clearAuth() }) {
            Label("Sign In", systemImage: "person.crop.circle.badge.plus")
          }
        } else {
          Button(action: { authStorage.clearAuth() }) {
            Label("Sign Out", systemImage: "person.crop.circle.fill.badge.minus")
          }
        }
      }
    } label: {
      let icon = shouldLogin ? "person.crop.circle" : "person.crop.circle.fill"
      Label("Me", systemImage: icon)
    }
      .imageScale(.large)
      .onAppear { loadData() }
      .onChange(of: authStorage.authInfo) { _ in loadData() }
      .background { navigationBackgrounds }
  }

  func loadData() {
    let uid = authStorage.authInfo.inner.uid
    logicCallAsync(.remoteUser(.with { $0.userID = uid })) { (response: RemoteUserResponse) in
      if response.hasUser {
        self.user = response.user
      }
    }
  }
}
