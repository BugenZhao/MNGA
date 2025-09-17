//
//  ContentView.swift
//  Shared
//
//  Created by Bugen Zhao on 6/27/21.
//

import BetterSafariView
import SwiftUI
import SwiftUIX

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
  @StateObject var schemes = SchemesModel()

  // For preview usage. If set, the content will be replaced by this.
  // In this case, `ContentView` mainly serves as a container for global states.
  var testBody: AnyView?

  var useColumnStyle: Bool {
    UserInterfaceIdiom.current == .pad
  }

  var main: some View {
    ForumListView()
      .modifier(SchemesNavigationModifier(model: schemes))
  }

  @ViewBuilder
  var realBody: some View {
    // Use `NavigationSplitView` on iPad.
    //
    // - Each column has its own navigation stack. Purposes are explained below.
    // - `NavigationLink` will by default push to the stack of the next column.
    //   Specify `isDetailLink(false)` to push to the current column.
    // - `.navigationDestination` will always push to the current column. Haven't
    //   found a way to override this behavior.
    if useColumnStyle {
      NavigationSplitView {
        // Forum search may be pushed to this stack.
        NavigationStack {
          main
        }
      } content: {
        // Subforum, hot/recommended topics may be pushed to this stack.
        NavigationStack {
          TopicListPlaceholderView()
        }
      } detail: {
        // User profile, detailed reading may be pushed to this stack.
        NavigationStack {
          TopicDetailsPlaceholderView()
        }
      }
    } else {
      NavigationStack {
        main
      }
    }
  }

  var body: some View {
    testBody ?? realBody.eraseToAnyView()
    #if os(iOS)
      .safariView(item: $openURL.inAppURL) { url in SafariView(url: url).preferredControlAccentColor(Color("AccentColor")) }
    #endif
      .onOpenURL { _ = schemes.onNavigateToURL($0) }
      .fullScreenCover(isPresented: $authStorage.isSigning) { LoginView() }
      .onAppear { if !authStorage.signedIn { authStorage.isSigning = true } }
      .sheet(isPresented: $activity.activityItems.isNotNil(), content: {
        AppActivityView(activityItems: activity.activityItems ?? [])
      })
      .modifier(MainToastModifier())
      .sheet(isPresented: $notis.showingSheet) { NotificationListNavigationView() }
      .sheet(isPresented: $postReply.showEditor) { PostEditorView().environmentObject(postReply) }
      .sheet(isPresented: $shortMessagePost.showEditor) { ShortMessageEditorView().environmentObject(shortMessagePost) }
      .sheet(isPresented: $textSelection.text.isNotNil()) { TextSelectionView().environmentObject(textSelection).presentationDetents([.medium, .large]) }
      .fullScreenCover(isPresented: $viewingImage.showing) { NewImageViewer() }
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
