//
//  ContentView.swift
//  Shared
//
//  Created by Bugen Zhao on 6/27/21.
//

import BetterSafariView
import SwiftUI
import SwiftUIX

@Observable class Router {
  var path = NavigationPath()
}

struct ContentView: View {
  @State var router = Router()

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
  @StateObject var schemes = SchemesModel()

  @SceneStorage("selectedForum") var selectedForum = WrappedMessage(inner: Forum())

  // For preview usage. If set, the content will be replaced by this.
  // In this case, `ContentView` mainly serves as a container for global states.
  var testBody: AnyView?

  var useColumnStyle: Bool {
    UserInterfaceIdiom.current == .pad || UserInterfaceIdiom.current == .mac
  }

  var main: some View {
    ForumListView()
      .modifier(SchemesNavigationModifier(model: schemes))
  }

  @ViewBuilder
  var realBody: some View {
    if useColumnStyle {
      NavigationView {
        main
        if selectedForum.inner != Forum() {
          TopicListView.build(forum: selectedForum.inner)
        } else {
          TopicListPlaceholderView()
        }
        TopicDetailsPlaceholderView()
      }
    } else {
      NavigationStack(path: $router.path) {
        main
      }
    }
  }

  var body: some View {
    (testBody ?? realBody.eraseToAnyView())
      .environment(router)
    #if os(iOS)
      .safariView(item: $openURL.inAppURL) { url in SafariView(url: url).preferredControlAccentColor(Color("AccentColor")) }
    #endif
      .onOpenURL { _ = schemes.onNavigateToURL($0) }
      .overlay { ImageOverlay() }
      .fullScreenCover(isPresented: $authStorage.isSigning) { LoginView() }
      .onAppear { if !authStorage.signedIn { authStorage.isSigning = true } }
      .sheet(isPresented: $activity.activityItems.isNotNil(), content: {
        AppActivityView(activityItems: activity.activityItems ?? [])
      })
      .modifier(MainToastModifier())
      .sheet(isPresented: $notis.showingSheet) { NotificationListNavigationView() }
      .sheet(isPresented: $postReply.showEditor) { PostEditorView().environmentObject(postReply) }
      .sheet(isPresented: $shortMessagePost.showEditor) { ShortMessageEditorView().environmentObject(shortMessagePost) }
      .sheet(isPresented: $textSelection.text.isNotNil()) { TextSelectionView().environmentObject(textSelection) }
      .environmentObject(viewingImage)
      .environmentObject(activity)
      .environmentObject(postReply)
      .environmentObject(shortMessagePost)
      .environmentObject(currentUser)
      .environmentObject(textSelection)
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
