//
//  ContentView.swift
//  Shared
//
//  Created by Bugen Zhao on 6/27/21.
//

import SwiftUI
import SwiftUIX
import BetterSafariView

struct ContentView: View {
  @StateObject var viewingImage = ViewingImageModel()
  @StateObject var activity = ActivityModel()
  @StateObject var prefs = PreferencesStorage.shared
  @StateObject var openURL = OpenURLModel.shared

  @SceneStorage("selectedForum") var selectedForum = WrappedMessage(inner: Forum())

  var body: some View {
    Group {
      if UserInterfaceIdiom.current == .pad || UserInterfaceIdiom.current == .mac {
        NavigationView {
          ForumListView()
          if selectedForum.inner != Forum() {
            TopicListView.build(forum: selectedForum.inner)
          } else {
            TopicListPlaceholderView()
          }
          EmptyView()
        }
      } else {
        NavigationView {
          ForumListView()
          if selectedForum.inner != Forum() {
            TopicListView.build(forum: selectedForum.inner)
          }
        }
      }
    } .overlay { ImageOverlay() }
      .safariView(item: $openURL.inAppURL) { url in SafariView(url: url).preferredControlAccentColor(Color("AccentColor")) }
      .sheet(isPresented: $activity.activityItems.isNotNil(), content: {
        AppActivityView(activityItems: activity.activityItems ?? [])
      })
      .modifier(HudToastModifier())
      .environmentObject(viewingImage)
      .environmentObject(activity)
      .environment(\.useRedact, prefs.useRedact)
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    Group {
      ContentView()
    }
  }
}
