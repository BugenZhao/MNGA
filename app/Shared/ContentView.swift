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
  @StateObject var paywall = PaywallModel.shared

  @Environment(\.scenePhase) var scenePhase

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
      .onOpenURL { schemes.navigateTo(url: $0) }
      .onChange(of: scenePhase) { paywall.objectWillChange.send() } // trigger trial validity check
      .modifier(MainToastModifier.main())
      .preferredColorScheme(prefs.colorScheme.scheme)
      // Sheets
      .safariView(item: $openURL.inAppURL) { url in SafariView(url: url).preferredControlAccentColor(Color("AccentColor")) } // this is global-wide, no need to attribute again in sheets
      .sheet(isPresented: $authStorage.isSigning) { LoginView() }
      .sheet(isPresented: $activity.activityItems.isNotNil(), content: {
        AppActivityView(activityItems: activity.activityItems ?? [])
      })
      .sheet(isPresented: $notis.showingSheet) { NotificationListNavigationView() }
      .modifier(GlobalSheetsModifier())
      // Global states
      .environmentObject(viewingImage)
      .environmentObject(activity)
      .environmentObject(postReply)
      .environmentObject(shortMessagePost)
      .environmentObject(currentUser)
      .environmentObject(textSelection)
      .environmentObject(paywall)
  }
}

/// Enable global sheets, including post reply, short message, text selection.
///
/// This should be applied to each different navigation stack. For example, the root one
/// and the one in notification sheet.
struct GlobalSheetsModifier: ViewModifier {
  @EnvironmentObject var postReply: PostReplyModel
  @EnvironmentObject var shortMessagePost: ShortMessagePostModel
  @EnvironmentObject var textSelection: TextSelectionModel
  @EnvironmentObject var viewingImage: ViewingImageModel
  @StateObject var prefs = PreferencesStorage.shared

  func body(content: Content) -> some View {
    content
      .sheet(isPresented: $postReply.showEditor) { PostEditorView() }
      .sheet(isPresented: $shortMessagePost.showEditor) { ShortMessageEditorView() }
      .sheet(isPresented: $textSelection.text.isNotNil()) { TextSelectionView().presentationDetents([.medium, .large]) }
      .sheet(isPresented: $prefs.showing) { PreferencesView() }
      .modifier(PaywallSheetModifier())
      .fullScreenCover(isPresented: $viewingImage.showing) { NewImageViewer() }
  }
}

struct PaywallSheetModifier: ViewModifier {
  @EnvironmentObject var paywall: PaywallModel

  func body(content: Content) -> some View {
    content
      .sheet(isPresented: $paywall.isShowingModal) { PlusSheetView() }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    Group {
      ContentView()
    }
  }
}
