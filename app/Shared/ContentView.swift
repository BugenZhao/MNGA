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
  @StateObject var notis = NotificationModel.shared
  @StateObject var currentUser = CurrentUserModel()
  @StateObject var textSelection = TextSelectionModel()

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
        }
      }
    } .overlay { ImageOverlay() }
      .fullScreenCover(isPresented: $authStorage.isSigning) { LoginView() }
      .onAppear { if !authStorage.signedIn { authStorage.isSigning = true } }
    #if os(iOS)
      .safariView(item: $openURL.inAppURL) { url in SafariView(url: url).preferredControlAccentColor(Color("AccentColor")) }
    #endif
    .sheet(isPresented: $activity.activityItems.isNotNil(), content: {
        AppActivityView(activityItems: activity.activityItems ?? [])
      })
      .modifier(HudToastModifier())
      .sheet(isPresented: $postReply.showEditor) { PostEditorView() }
      .sheet(isPresented: $shortMessagePost.showEditor) { ShortMessageEditorView() }
      .sheet(isPresented: $notis.showingSheet) { NotificationListNavigationView() }
      .sheet(isPresented: $textSelection.text.isNotNil()) { TextSelectionView() }
      .environmentObject(viewingImage)
      .environmentObject(activity)
      .environmentObject(postReply)
      .environmentObject(shortMessagePost)
      .environmentObject(currentUser)
      .environmentObject(textSelection)
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
