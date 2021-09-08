//
//  TopicDetailsView.swift
//  NGA
//
//  Created by Bugen Zhao on 6/28/21.
//

import Foundation
import SwiftUI
import SwiftUIX
import Combine
import SwiftUIRefresh

class TopicDetailsActionModel: ObservableObject {
  @Published var scrollToPid: String? = nil

  @Published var navigateToTid: String? = nil
}

struct TopicDetailsView: View {
  let topic: Topic

  @EnvironmentObject var activity: ActivityModel
  @EnvironmentObject var viewingImage: ViewingImageModel

  @StateObject var dataSource: PagingDataSource<TopicDetailsResponse, Post>
  @StateObject var action = TopicDetailsActionModel()
  @StateObject var votes = VotesModel()
  @StateObject var postReply = PostReplyModel()
  @StateObject var prefs = PreferencesStorage.shared
  @StateObject var users = UsersModel.shared
  @StateObject var alert = ToastModel.alert

  @State var isFavored: Bool

  static func build(topic: Topic) -> Self {
    let dataSource = PagingDataSource<TopicDetailsResponse, Post>(
      buildRequest: { page in
        return .topicDetails(TopicDetailsRequest.with {
          $0.topicID = topic.id
          if topic.hasFav { $0.fav = topic.fav }
          $0.page = UInt32(page)
        })
      },
      onResponse: { response in
        let items = response.replies
        let pages = response.pages
        return (items, Int(pages))
      },
      id: \.floor.description
    )

    return Self.init(topic: topic, dataSource: dataSource, isFavored: topic.isFavored)
  }

  private var first: Post? { dataSource.items.first }

  private var latestTopic: Topic {
    var latest = self.topic
    if let newTopic = self.dataSource.latestResponse?.topic {
      latest.tags = newTopic.tags
      latest.subjectContent = newTopic.subjectContent
    }
    return latest
  }

  @ViewBuilder
  var moreMenu: some View {
    Menu {
      Section {
        Button(action: { toggleFavor() }) {
          Label(
            isFavored ? "Remove from Favorites" : "Mark as Favorite",
            systemImage: isFavored ? "bookmark.slash.fill" : "bookmark"
          )
        }
        Button(action: { self.doReplyTopic() }) {
          Label("Reply", systemImage: "arrowshape.turn.up.left")
        }
      }
      Section {
        Button(action: { self.activity.put(URL(string: webpageURL)) }) {
          Label("Share", systemImage: "square.and.arrow.up")
        }
        Button(action: self.shareAsImage) {
          Label("Share As Image", systemImage: "text.below.photo")
        }
      }
      Section {
        Button(action: { self.dataSource.refresh() }) {
          Label("Refresh", systemImage: "arrow.clockwise")
        }
        Label("#" + topic.id, systemImage: "number")
        if topic.hasFav {
          Label(topic.fav, systemImage: "bookmark.fill")
        }
      }
    } label: {
      Label("More", systemImage: "ellipsis.circle")
        .imageScale(.large)
    }
  }

  @ViewBuilder
  func buildRow(post: Post, withId: Bool = true) -> some View {
    PostRowView(post: post, useContextMenu: !prefs.usePaginatedDetails, vote: votes.binding(for: post))
      .id((withId ? "" : "dummy") + post.id.pid)
  }

  @ViewBuilder
  var headerSectionInner: some View {
    TopicSubjectView(topic: latestTopic, lineLimit: nil)
      .fixedSize(horizontal: false, vertical: true)
    if let first = self.first {
      buildRow(post: first)
    }
//    else {
//      LoadingRowView(high: true)
//    }
  }

  @ViewBuilder
  var headerSection: some View {
    Section(header: Text("Topic")) {
      headerSectionInner
    } .transition(.asymmetric(insertion: .scale, removal: .opacity))
  }

  @ViewBuilder
  var hotRepliesSection: some View {
    if let hotReplies = self.first?.hotReplies, !hotReplies.isEmpty {
      Section(header: Text("Hot Replies")) {
        ForEach(hotReplies, id: \.id.pid) { post in
          buildRow(post: post, withId: false)
        }
      }
    }
  }

  @ViewBuilder
  var allRepliesSection: some View {
    if dataSource.items.count > 1 {
      Section(header: Text("Replies")) {
        ForEach(dataSource.sortedItems(by: \.floor).dropFirst(), id: \.id.pid) { post in
          buildRow(post: post)
            .onAppear { dataSource.loadMoreIfNeeded(currentItem: post) }
        }
      }
    }
  }

  @ViewBuilder
  var navigation: some View {
    let topic = Topic.with {
      if let tid = self.action.navigateToTid { $0.id = tid }
    }
    NavigationLink(destination: TopicDetailsView.build(topic: topic), isActive: self.$action.navigateToTid.isNotNil()) { }
  }

  @ViewBuilder
  var listMain: some View {
    List {
      headerSection
      hotRepliesSection
      allRepliesSection
    }
    #if os(iOS)
      .listStyle(GroupedListStyle())
    #endif
  }

  @ViewBuilder
  func buildStack(_ items: Array<Post>.SubSequence) -> some View {
    VStack(alignment: .leading) {
      ForEach(items, id: \.id.pid) { post in
        buildRow(post: post)
        if post.id != items.last?.id {
          Divider()
            .padding(.trailing, -20)
        }
      }
    } .fixedSize(horizontal: false, vertical: true)
  }

  @ViewBuilder
  var listStackHotRepliesSection: some View {
    if let hotReplies = self.first?.hotReplies, !hotReplies.isEmpty {
      Section(header: Text("Hot Replies")) {
        buildStack(hotReplies[...])
      }
    }
  }

  @ViewBuilder
  var listStackAllRepliesSections: some View {
    if dataSource.items.count > 1 {
      ForEach(dataSource.pagedItems, id: \.page) { pair in
        Section(header: Text("Page \(pair.page)")) {
          let items = pair.items.dropFirst(pair.page == 1 ? 1 : 0)
          buildStack(items)
        }
      }

      if let nextPage = dataSource.nextPage {
        let loadTrigger = Text("").onAppear { dataSource.loadMore(after: 0.7) }
        Section(header: Text("Page \(nextPage)"), footer: loadTrigger) {
          // BUGEN'S HACK:
          // the first view of this section will unexpectedly call `onAppear(_:)`
          // even if we are scrolling the previous section.
          // While the next ones won't, this can not be a solution since displaying
          // TWO dummy views here seems too strange for users.
          // Fortunately, using `onAppear(_:)` on the footer of the section works.
          // Note that the `.id(_:)` on this section is necessary, or the `onAppear`
          // trigger can not be triggered again.
          LoadingRowView()
        } .id(nextPage)
      }
    }
  }

  @ViewBuilder
  var listStackMain: some View {
    List {
      headerSection
      listStackHotRepliesSection
      listStackAllRepliesSections
    }
    #if os(iOS)
      .listStyle(GroupedListStyle())
    #endif
  }

  var body: some View {
    VStack(alignment: .leading) {
      ScrollViewReader { proxy in
        Group {
          if prefs.usePaginatedDetails {
            listStackMain
          } else {
            listMain
          }
        } .environmentObject(action)
          .onReceive(action.$scrollToPid) { pid in
          withAnimation { proxy.scrollTo(pid) }
        }
      }
    }
      .navigationTitle(prefs.showTopicSubject ? latestTopic.subjectContent : NSLocalizedString("Topic", comment: ""))
      .modifier(SingleItemToolbarModifier { moreMenu })
      .sheet(isPresented: $postReply.showEditor) { PostEditorView().environmentObject(postReply) }
      .background { navigation }
      .onChange(of: postReply.sent, perform: self.reloadPageAfter(sent:))
      .onChange(of: dataSource.latestResponse, perform: self.preloadUsers(response:))
      .environmentObject(postReply)
      .onAppear { dataSource.initialLoad() }
    #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
//      .pullToRefresh(isShowing: .constant(dataSource.isRefreshing)) { dataSource.refresh() }
    #endif
    .userActivity(Constants.Activity.openTopic) { activity in
      if let url = URL(string: webpageURL) {
        activity.webpageURL = url
      }
    }
  }

  var webpageURL: String {
    "\(Constants.URL.base)/read.php?tid=\(topic.id)" + (topic.hasFav ? "&fav=\(topic.fav)" : "")
  }

  func toggleFavor() {
    logicCallAsync(.topicFavor(.with {
      $0.topicID = topic.id
      $0.operation = self.isFavored ? .delete : .add
    })) { (response: TopicFavorResponse) in
      self.isFavored = response.isFavored
      #if os(iOS)
        HapticUtils.play(type: .success)
      #endif
    }
  }

  func doReplyTopic() {
    self.postReply.show(action: .with {
      $0.operation = .reply
      $0.postID = .with {
        $0.tid = self.topic.id
        $0.pid = "0"
      }
    }, pageToReload: .last)
  }

  func reloadPageAfter(sent: PostReplyModel.Context?) {
    guard let sent = sent else { return }

    switch sent.task.pageToReload {
    case .exact(let page):
      dataSource.reload(page: page, evenIfNotLoaded: false)
    case .last:
      dataSource.reloadLastPages(evenIfNotLoaded: false)
    case .none:
      break
    }
  }

  func preloadUsers(response: TopicDetailsResponse?) {
//    if let response = response {
//      DispatchQueue.main.async {
//        for id in response.replies.map(\.authorID) {
//          let _ = self.users.localUser(id: id)
//        }
//      }
//    }
  }

  @ViewBuilder
  var screenshotView: some View {
    VStack(alignment: .leading) {
      headerSectionInner

      if let hotReplies = self.first?.hotReplies, !hotReplies.isEmpty {
        Spacer()
          .height(20)
        Text("Hot Replies")
          .font(.footnote)
          .foregroundColor(.secondary)
        ForEach(hotReplies, id: \.id.pid) { post in
          Divider()
          buildRow(post: post, withId: false)
        }
      } else if let latestReplies = dataSource.sortedItems(by: \.floor).dropFirst().prefix(5),
        !latestReplies.isEmpty
      {
        Spacer()
          .height(20)
        Text("Replies")
          .font(.footnote)
          .foregroundColor(.secondary)
        ForEach(latestReplies, id: \.id.pid) { post in
          Divider()
          buildRow(post: post, withId: false)
        } .fixedSize(horizontal: false, vertical: true)
      }
    }
      .padding()
      .background(.secondarySystemGroupedBackground)
      .frame(width: UIScreen.main.bounds.size.width)
      .environmentObject(action)
      .environmentObject(postReply)
  }

  func shareAsImage() {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      let image = screenshotView.snapshot()
      if image.size == .zero {
        self.alert.message = .error(NSLocalizedString("Contents are too large to take a screenshot.", comment: ""))
      } else {
        viewingImage.show(image: image)
      }
    }
  }
}


struct TopicDetailsView_Preview: PreviewProvider {
  static var previews: some View {
    AuthedPreview {
      NavigationView {
        TopicDetailsView.build(topic: Topic.with {
          $0.id = "27637920" // "27555218"
          $0.subjectContent = "Topic Title"
        })
      }
    }
  }
}
