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
    notification.unreadCount
  }

  @ViewBuilder
  var icon: some View {
    let icon = Image(systemName: authStorage.signedIn ? "person.crop.circle.fill" : "person.crop.circle")

    WebImage(url: URL(string: user?.avatarURL ?? "")) {
      ($0.image ?? icon).resizable()
    }
    .clipShape(Circle())
    .overlay(Circle().stroke(Color.accentColor, lineWidth: 1))
    .frame(width: 24, height: 24)
    .id("user-menu-icon-\(user?.avatarURL ?? "")") // workaround not updating when url changes from nil to valid
  }

  @ViewBuilder
  var notificationButton: some View {
    Button(action: {
      if UserInterfaceIdiom.current == .pad {
        // Always show as sheet on iPad.
        notification.showingSheet = true
      } else {
        notification.showingFromUserMenu = true
      }
    }) {
      Label("Notifications", systemImage: unreadCount > 0 ? "bell.badge.fill" : "bell")
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
          .onChange(of: authStorage.authInfo) { FavoriteFolderModel.shared.reset() }
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
          NavigationLink(destination: FavoriteTopicListView()) {
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
      .onChange(of: authStorage.authInfo.uid, initial: true) { model.loadData(uid: $1) }
      .sheet(isPresented: $showAboutViewAsModal) { AboutNavigationView() }
      .popoverTip(tip)
      .navigationDestination(isPresented: $notification.showingFromUserMenu) { NotificationListView() }
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
