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
  @StateObject var postReply = PostReplyModel()
  @StateObject var shortMessagePost = ShortMessagePostModel()
  @StateObject var prefs = PreferencesStorage.shared
  @StateObject var openURL = OpenURLModel.shared
  @StateObject var authStorage = AuthStorage.shared

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
          TopicDetailsPlaceholderView()
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
      .sheet(isPresented: $authStorage.isSigning) { LoginView() }
      .onAppear { if !authStorage.signedIn { authStorage.isSigning = true } }
    #if os(iOS)
      .safariView(item: $openURL.inAppURL) { url in SafariView(url: url).preferredControlAccentColor(Color("AccentColor")) }
    #endif
    .sheet(isPresented: $activity.activityItems.isNotNil(), content: {
        AppActivityView(activityItems: activity.activityItems ?? [])
      })
      .modifier(HudToastModifier())
      .environmentObject(viewingImage)
      .environmentObject(activity)
      .environmentObject(postReply)
      .sheet(isPresented: $postReply.showEditor) { PostEditorView().environmentObject(postReply) }
      .environmentObject(shortMessagePost)
      .sheet(isPresented: $shortMessagePost.showEditor) { ShortMessageEditorView().environmentObject(shortMessagePost) }
      .environment(\.useRedact, prefs.useRedact)
      .preferredColorScheme(prefs.colorScheme.scheme)
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    Group {
      ContentView()
    }
  }
}
