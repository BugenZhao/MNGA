//
//  UserMenuView.swift
//  NGA
//
//  Created by Bugen Zhao on 7/14/21.
//

import Foundation
import SDWebImageSwiftUI
import SwiftUI

struct UserMenuView: View {
  @StateObject var notification = NotificationModel.shared
  @StateObject var authStorage = AuthStorage.shared

  @EnvironmentObject var model: CurrentUserModel

  @State var showHistory: Bool = false
  @State var showFavorite: Bool = false
  @State var showNotifications: Bool = false
  @State var showShortMessages: Bool = false
  @State var showPreferencesModal: Bool = false
  @State var showAbout: Bool = false
  @State var showUserProfile: Bool = false

  var user: User? {
    model.user
  }

  @ViewBuilder
  var navigationBackgrounds: some View {
    NavigationLink(destination: TopicHistoryListView.build(), isActive: $showHistory) {}.hidden()
    NavigationLink(destination: FavoriteTopicListView.build(), isActive: $showFavorite) {}.hidden()
    NavigationLink(destination: NotificationListView(), isActive: $showNotifications) {}.hidden()
    NavigationLink(destination: ShortMessageListView.build(), isActive: $showShortMessages) {}.hidden()
    NavigationLink(destination: UserProfileView.build(user: user ?? .init()), isActive: $showUserProfile) {}.hidden()
    NavigationLink(destination: AboutView(), isActive: $showAbout) {}.hidden()
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
    Button(action: { showNotifications = true }) {
      Label(notification.dataSource.title, systemImage: notification.dataSource.unreadCount > 0 ? "bell.badge.fill" : "bell")
    }.maySymbolRenderingModeHierarchical()
  }

  @ViewBuilder
  var userSwitcher: some View {
    Menu {
      if authStorage.allAuthInfos.count > 1 {
        Picker("Accounts", selection: $authStorage.authInfo) {
          ForEach(authStorage.allAuthInfos.sorted(by: { $0.uid < $1.uid }), id: \.uid) { info in
            Text(info.cachedName.isEmpty ? info.uid : info.cachedName).tag(info)
          }
        }
      }

      Button(action: { addUser() }) {
        Label("Add Account", systemImage: "person.crop.circle.fill.badge.plus")
      }
      Button(action: { reSignIn() }) {
        Label("Sign Out", systemImage: "person.crop.circle.fill.badge.minus")
      }
    } label: {
      Label(user?.name.display ?? authStorage.authInfo.uid, systemImage: "person")
    }
  }

  @ViewBuilder
  var menu: some View {
    Menu {
      if let _ = self.user {
        Section {
          notificationButton
          Button(action: { showShortMessages = true }) {
            Label("Short Messages", systemImage: "message")
          }
        }
      }
      Section {
        if let _ = self.user {
          Button(action: { showUserProfile = true }) {
            Label("My Profile", systemImage: "person.fill")
          }
          Button(action: { showFavorite = true }) {
            Label("Favorite Topics", systemImage: "bookmark")
          }
        }
        Button(action: { showHistory = true }) {
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
          Button(action: { showPreferencesModal = true }) {
            Label("Preferences", systemImage: "gear")
          }
        #endif
        Button(action: { showAbout = true }) {
          Label("About & Feedback", systemImage: "hands.sparkles")
        }
      }
    } label: {
      icon
    }
  }

  var body: some View {
    HStack {
      menu
      if notification.dataSource.unreadCount > 0 {
        notificationButton
      }
    }.imageScale(.large)
      .onAppear { model.loadData(uid: authStorage.authInfo.uid) }
      .onAppear { notification.showing = true }
      .onDisappear { notification.showing = false }
      .background { navigationBackgrounds }
      .sheet(isPresented: $showPreferencesModal) { PreferencesView() }
  }

  func reSignIn() {
    authStorage.clearCurrentAuth()
    if !authStorage.signedIn {
      authStorage.isSigning = true
    }
  }

  func addUser() {
    authStorage.isSigning = true
  }
}
