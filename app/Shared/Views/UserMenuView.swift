//
//  UserMenuView.swift
//  NGA
//
//  Created by Bugen Zhao on 7/14/21.
//

import Foundation
import SDWebImageSwiftUI
import SwiftUI
import SwiftUIX
import TipKit

struct UserMenuView: View {
  @StateObject var notification = NotificationModel.shared
  @StateObject var authStorage = AuthStorage.shared
  @StateObject var prefs = PreferencesStorage.shared

  @EnvironmentObject var model: CurrentUserModel

  @State var showAboutViewAsModal: Bool = false

  var user: User? {
    model.user
  }

  var unreadCount: Int {
    notification.dataSource.unreadCount
  }

  @ViewBuilder
  var icon: some View {
    let icon = Image(systemName: authStorage.signedIn ? "person.crop.circle.fill" : "person.crop.circle")
    #if os(iOS)
      WebOrAsyncImage(url: URL(string: user?.avatarURL ?? ""), placeholder: icon.resizable())
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.accentColor, lineWidth: 1))
        .frame(width: 24, height: 24)
    #else
      icon
    #endif
  }

  @ViewBuilder
  var notificationButton: some View {
    NavigationLink(destination: NotificationListView()) {
      Label(notification.dataSource.title, systemImage: unreadCount > 0 ? "bell.badge.fill" : "bell")
    }
  }

  @ViewBuilder
  var aboutButton: some View {
    let label = Label("About & Feedback", systemImage: "hands.sparkles")

    if UserInterfaceIdiom.current == .pad {
      Button(action: { showAboutViewAsModal = true }) {
        label
      }
    } else {
      NavigationLink(destination: AboutView()) {
        label
      }
    }
  }

  @ViewBuilder
  var userSwitcher: some View {
    Menu {
      if authStorage.allAuthInfos.count > 1 {
        Picker("Accounts", selection: $authStorage.authInfo) {
          ForEach(authStorage.allAuthInfos.sorted(by: { $0.uid < $1.uid }), id: \.uid) { info in
            Text(info.cachedName.isEmpty ? info.uid : info.cachedName).tag(info)
          }
        }.disableWithPlusCheck(.multiAccount)
      }

      Button(action: { withPlusCheck(.multiAccount) { addUser() } }) {
        Label("Add Account", systemImage: "person.crop.circle.fill.badge.plus")
      }
      Button(role: .destructive, action: { signOut() }) {
        Label("Sign Out", systemImage: "person.crop.circle.fill.badge.minus")
      }
    } label: {
      Label("Accounts", systemImage: "person.2")
      Text(user?.name.display ?? authStorage.authInfo.uid)
    }
  }

  @ViewBuilder
  var menu: some View {
    Menu {
      if let _ = user {
        Section {
          notificationButton
          PlusCheckNavigationLink(destination: ShortMessageListView.build(), feature: .shortMessage) {
            Label("Short Messages", systemImage: "message")
          }
        }
      }
      Section {
        if let user {
          NavigationLink(destination: UserProfileView.build(user: user)) {
            Label("My Profile", systemImage: "person.text.rectangle")
          }
          NavigationLink(destination: FavoriteTopicListView.build()) {
            Label("Favorite Topics", systemImage: "bookmark")
          }
        }
        PlusCheckNavigationLink(destination: TopicHistoryListView.build(), feature: .topicHistory) {
          Label("History", systemImage: "clock")
        }
      }
      Section {
        if authStorage.signedIn {
          userSwitcher
        } else {
          Button(action: { reSignIn() }) {
            Label("Sign In", systemImage: "person.crop.circle.badge.plus")
          }
        }
      }
      Section {
        #if os(iOS)
          Button(action: { prefs.showing = true }) {
            Label("Settings", systemImage: "gear")
          }
        #endif
        aboutButton
      }
    } label: {
      icon
    }
  }

  var body: some View {
    menu
      .badge(unreadCount)
      .onChange(of: authStorage.authInfo.uid, initial: true) { model.loadData(uid: $1) }
      .onAppear { notification.showing = true }
      .onDisappear { notification.showing = false }
      .sheet(isPresented: $showAboutViewAsModal) { AboutNavigationView() }
      .popoverTip(tip)
  }

  func signOut() {
    authStorage.clearCurrentAuth()
  }

  // Sign out and pop the sign in sheet.
  func reSignIn() {
    authStorage.clearCurrentAuth()
    if !authStorage.signedIn {
      authStorage.isSigning = true
    }
  }

  func addUser() {
    authStorage.isSigning = true
  }

  var tip: (any Tip)? {
    if !authStorage.signedIn {
      UserMenuTip()
    } else {
      nil
    }
  }
}

struct UserMenuTip: Tip {
  var title: Text {
    Text("MNGA Main Menu")
  }

  var message: Text? {
    Text("Sign in to NGA and discover more features here.")
  }

  var options: [Option] {
    MaxDisplayCount(1)
  }
}
