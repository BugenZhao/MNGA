//
//  TopicDetailsView.swift
//  NGA
//
//  Created by Bugen Zhao on 6/28/21.
//

import Foundation
import SwiftUI
import SwiftUIX

struct TopicDetailsView: View {
  typealias DataSource = PagingDataSource<TopicDetailsResponse, Post>

  @State var topic: Topic

  @Environment(\.enableAuthorOnly) var enableAuthorOnly
  @Environment(\.currentlyLocalMode) var localMode
  @EnvironmentObject var activity: ActivityModel
  @EnvironmentObject var viewingImage: ViewingImageModel
  @EnvironmentObject var postReply: PostReplyModel

  @StateObject var dataSource: DataSource
  @StateObject var action = TopicDetailsActionModel()
  @StateObject var votes = VotesModel()
  @StateObject var prefs = PreferencesStorage.shared
  @StateObject var users = UsersModel.shared
  @StateObject var alert = ToastModel.alert

  @State var isFavored: Bool

  let onlyPost: (id: PostId?, atPage: Int?)

  @State var showJumpSelector = false
  @State var floorToJump: Int?
  @State var postIdToJump: PostId?

  static func build(id: String) -> some View {
    Self.build(topic: .with { $0.id = id })
  }

  static func build(onlyPost: (id: PostId, atPage: Int?)) -> some View {
    let topic = Topic.with { $0.id = onlyPost.id.tid }
    return Self.build(topic: topic, onlyPost: onlyPost)
  }

  static func build(topic: Topic, localMode: Bool = false, onlyPost: (id: PostId?, atPage: Int?) = (nil, nil), fromPage: Int? = nil, postIdToJump: PostId? = nil) -> some View {
    let dataSource = DataSource(
      buildRequest: { page in
        return .topicDetails(TopicDetailsRequest.with {
          $0.topicID = topic.id
          if topic.hasFav { $0.fav = topic.fav }
          if let pid = onlyPost.id?.pid { $0.postID = pid }
          $0.localCache = localMode
          $0.page = UInt32(page)
        })
      },
      onResponse: { response in
        let items = response.replies
        let pages = response.pages
        return (items, Int(pages))
      },
      id: \.floor.description,
      finishOnError: localMode,
      loadFromPage: fromPage
    )

    return Self.init(topic: topic, dataSource: dataSource, isFavored: topic.isFavored, onlyPost: onlyPost, postIdToJump: postIdToJump)
      .environment(\.enableAuthorOnly, !localMode)
      .environment(\.currentlyLocalMode, localMode)
  }

  static func build(topic: Topic, only authorID: String) -> some View {
    let dataSource = DataSource(
      buildRequest: { page in
        return .topicDetails(TopicDetailsRequest.with {
          $0.topicID = topic.id
          if topic.hasFav { $0.fav = topic.fav }
          $0.authorID = authorID
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

    return Self.init(topic: topic, dataSource: dataSource, isFavored: topic.isFavored, onlyPost: (nil, nil))
      .environment(\.enableAuthorOnly, false)
  }

  private var first: Post? {
    if let first = dataSource.items.first, first.id.pid == "0" {
      return first
    } else {
      return nil
    }
  }

  private var shouldShowReplies: Bool {
    dataSource.items.contains(where: { $0.id != first?.id })
  }

  private var atForum: Forum? {
    guard let forumName = dataSource.latestResponse?.forumName, forumName != "" else { return nil }
    guard let fid = dataSource.items.first?.fid else { return nil }
    return Forum.with {
      $0.id = .with { i in i.fid = fid }
      $0.name = forumName
    }
  }

  @ViewBuilder
  var progress: some View {
    if dataSource.isLoading {
      ProgressView()
    }
  }

  @ViewBuilder
  var replyButton: some View {
    Button(action: { self.doReplyTopic() }) {
      Label("Reply", systemImage: "arrowshape.turn.up.left")
    }
  }

  @ViewBuilder
  var favoriteButton: some View {
    Button(action: { toggleFavor() }) {
      Label(
        isFavored ? "Remove from Favorites" : "Mark as Favorite",
        systemImage: isFavored ? "bookmark.slash.fill" : "bookmark"
      )
    }
  }

  @ViewBuilder
  var moreMenu: some View {
    Menu {
      #if os(iOS)
        Section {
          replyButton
        }
      #endif

      Section {
        if enableAuthorOnly {
          Button(action: { self.action.navigateToAuthorOnly = self.topic.authorID }) {
            Label("Author Only", systemImage: "person.fill")
          }
        }
        if !localMode {
          Button(action: { self.action.navigateToLocalMode = true }) {
            Label("View Cached Topic", systemImage: "clock")
          }
        }
        Button(action: { self.showJumpSelector = true }) {
          Label("Jump to...", systemImage: "arrow.up.arrow.down")
        }
      }

      #if os(iOS)
        Section {
          Button(action: { self.activity.put(webpageURL) }) {
            Label("Share", systemImage: "square.and.arrow.up")
          }
          Button(action: self.shareAsImage) {
            Label("Share As Image", systemImage: "text.below.photo")
          }
        }
      #endif

      #if os(iOS)
        Section {
          favoriteButton
        }
      #endif

      Section {
        if let atForum = atForum {
          Button(action: { self.action.navigateToForum = atForum }) {
            Label("Goto \(atForum.name)", systemImage: "list.triangle")
          }
        }
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
  var menu: some View {
    if let postId = onlyPost.id {
      let view = TopicDetailsView.build(topic: topic, fromPage: onlyPost.atPage, postIdToJump: postId).eraseToAnyView()
      Button(action: { action.navigateToView = view }) {
        Label("See Full Topic", systemImage: "doc.richtext")
      }
    } else {
      moreMenu
    }
  }

  @ViewBuilder
  var mayLoadBackButton: some View {
    if let _ = dataSource.loadFromPage,
      let prevPage = dataSource.firstLoadedPage?.advanced(by: -1), prevPage >= 1,
      let currFirst = dataSource.items.min(by: { $0.floor < $1.floor }) {
      Button(action: {
        self.action.scrollToFloor = Int(currFirst.floor) // scroll to first for fixing scroll position
        dataSource.reload(page: prevPage, evenIfNotLoaded: true) {
          guard let floor = dataSource.itemsAtPage(prevPage).map(\.floor).max() else { return }
          DispatchQueue.main.async { self.action.scrollToFloor = Int(floor) } // scroll to last of prev page
        }
      }) {
        Label("Load Page \(prevPage)", systemImage: "arrow.counterclockwise")
      } .disabled(dataSource.isLoading)
    }
  }

  @ViewBuilder
  func buildRow(post: Post, withId: Bool = true) -> some View {
    let row = PostRowView(post: post, vote: votes.binding(for: post))

    if withId {
      row.id(post)
    } else {
      row
    }
  }

  @ViewBuilder
  var headerSectionInner: some View {
    TopicSubjectView(topic: topic, lineLimit: nil)
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
    if shouldShowReplies {
      Section(header: Text("Replies")) {
        mayLoadBackButton
        ForEach(dataSource.pagedItems, id: \.page) { pair in
          let items = pair.items.filter { $0.id != first?.id }
          ForEach(items, id: \.id.pid) { post in
            buildRow(post: post)
              .onAppear { dataSource.loadMoreIfNeeded(currentItem: post) }
          }
        }
      }
    }
  }

  @ViewBuilder
  var navigation: some View {
    let showingChain = self.action.showingReplyChain ?? .init()
    NavigationLink(destination: PostReplyChainView(baseDataSource: dataSource, votes: votes, chain: showingChain).environmentObject(postReply), isActive: self.$action.showingReplyChain.isNotNil()) { } .hidden()

    let authorOnlyView = TopicDetailsView.build(topic: topic, only: self.action.navigateToAuthorOnly ?? .init())
    NavigationLink(destination: authorOnlyView, isActive: self.$action.navigateToAuthorOnly.isNotNil()) { } .hidden()

    if !localMode {
      let localCacheView = TopicDetailsView.build(topic: topic, localMode: true)
      NavigationLink(destination: localCacheView, isActive: self.$action.navigateToLocalMode) { } .hidden()
    }
  }

  @ViewBuilder
  var listMain: some View {
    List {
      headerSection
      hotRepliesSection
      allRepliesSection
    }
  }

  @ViewBuilder
  var paginatedAllRepliesSectionsNew: some View {
    if shouldShowReplies {
      mayLoadBackButton

      ForEach(dataSource.pagedItems, id: \.page) { pair in
        Section(header: Text("Page \(pair.page)")) {
          let items = pair.items.filter { $0.id != first?.id }
          ForEach(items, id: \.id.pid) { post in
            buildRow(post: post)
          }
        }
      }

      if let nextPage = dataSource.nextPage {
        let loadTrigger = Text("").onAppear { dataSource.loadMore() }
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
        } .id("page\(nextPage)")
      }
    }
  }

  @ViewBuilder
  var paginatedMain: some View {
    List {
      headerSection
      hotRepliesSection
      paginatedAllRepliesSectionsNew
    }
  }

  var title: String {
    if localMode {
      return NSLocalizedString("Topic (Cached)", comment: "")
    } else if !enableAuthorOnly {
      return NSLocalizedString("Author Only", comment: "")
    } else if onlyPost.id != nil {
      return NSLocalizedString("Reply", comment: "")
    } else if prefs.showTopicSubject {
      return topic.subject.content
    } else {
      return NSLocalizedString("Topic", comment: "")
    }
  }

  @ViewBuilder
  var loadFirstPageButton: some View {
    if let _ = dataSource.loadFromPage {
      Button(action: { dataSource.loadFromPage = nil; floorToJump = nil }) {
        Label("Load First Page", systemImage: "arrow.up.to.line")
      }
    }
  }

  @ToolbarContentBuilder
  var toolbar: some ToolbarContent {
    #if os(iOS)
      ToolbarItem(placement: .navigationBarTrailing) { progress }
      ToolbarItem(placement: .navigationBarTrailing) { loadFirstPageButton }
      ToolbarItem(placement: .navigationBarTrailing) { menu }
    #elseif os(macOS)
      ToolbarItemGroup {
        replyButton
        Spacer()
        favoriteButton
        menu
        ShareMenu(items: [webpageURL as Any])
      }
    #endif
  }

  @ViewBuilder
  var main: some View {
    ScrollViewReader { proxy in
      Group {
        if prefs.usePaginatedDetails && onlyPost.id == nil {
          paginatedMain
        } else {
          listMain
        }
      } .onReceive(action.$scrollToFloor) { floor in
        guard let floor = floor else { return }
        let item = dataSource.items.first { $0.floor == UInt32(floor) }
        proxy.scrollTo(item, anchor: .top)
      } .onReceive(action.$scrollToPid) { pid in
        guard let pid = pid else { return }
        let item = dataSource.items.first { $0.id.pid == pid }
        proxy.scrollTo(item, anchor: .top)
      }
    } .mayGroupedListStyle()
      .withTopicDetailsAction(action: action)
      .onReceive(dataSource.$refreshedTimes) { _ in mayScrollToJumpFloor() }
      .sheet(isPresented: $showJumpSelector) { TopicJumpSelectorView(maxFloor: maxFloor, initialFloor: floorToJump ?? 0, floorToJump: $floorToJump, pageToJump: $dataSource.loadFromPage) }
  }

  var body: some View {
    main
      .navigationTitleInline(string: title)
      .toolbarWithFix { toolbar }
      .background { navigation }
      .onChange(of: postReply.sent, perform: self.reloadPageAfter(sent:))
      .onChange(of: dataSource.latestResponse, perform: self.onNewResponse(response:))
      .environmentObject(postReply)
      .onAppear { dataSource.initialLoad() }
      .userActivity(Constants.Activity.openTopic) { $0.webpageURL = webpageURL }
  }

  var maxFloor: Int {
    Int((dataSource.latestResponse?.topic ?? topic).repliesNum)
  }

  func mayScrollToJumpFloor() {
    guard let _ = dataSource.loadFromPage else { return }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
      withAnimation {
        if let floor = floorToJump {
          action.scrollToFloor = floor
        } else if let pid = postIdToJump?.pid {
          action.scrollToPid = pid
        }
      }
    }
  }

  var webpageURL: URL? {
    URL(string: "read.php?tid=\(topic.id)" + (topic.hasFav ? "&fav=\(topic.fav)" : ""), relativeTo: Constants.URL.base)?.absoluteURL
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
      $0.forumID = .with { f in
        f.fid = topic.fid
      }
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

  func onNewResponse(response: TopicDetailsResponse?) {
    guard let response = response else { return }
    let newTopic = response.topic
    if newTopic.hasParentForum {
      self.topic.parentForum = newTopic.parentForum
    }
    self.topic.authorID = newTopic.authorID
    self.topic.subject = newTopic.subject
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
        Text("Replies")
          .font(.footnote)
          .foregroundColor(.secondary)
        ForEach(latestReplies, id: \.id.pid) { post in
          Divider()
          buildRow(post: post, withId: false)
        }
      }
    }
      .padding()
      .fixedSize(horizontal: false, vertical: true)
      .frame(width: Screen.main.bounds.size.width)
      .background(.secondarySystemGroupedBackground)
      .withTopicDetailsAction(action: action)
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
          $0.subject = .with { s in
            s.content = "Topic Title"
          }
        })
      }
    }
  }
}
