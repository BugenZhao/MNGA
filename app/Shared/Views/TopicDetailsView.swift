//
//  TopicDetailsView.swift
//  NGA
//
//  Created by Bugen Zhao on 6/28/21.
//

import Foundation
import SwiftUI
import SwiftUIX

struct StaticTopicDetailsView<Content: View>: View {
  @State var topic: Topic
  let buildView: (_: Binding<Topic>) -> Content

  var body: some View {
    buildView($topic)
  }
}

// Track the floors currently on the screen.
final class CurrentViewingFloor {
  private(set) var floors: Set<Int> = []
  var highestSeen: Int?

  var currentLowest: Int? {
    floors.min()
  }

  func appear(_ floor: Int) {
    floors.insert(floor)
  }

  func disappear(_ floor: Int) {
    floors.remove(floor)
    highestSeen = max(highestSeen ?? 0, floor)
  }
}

struct TopicFavorMenuView: View {
  @Binding var topic: Topic
  @Binding var showingCreateFolderAlert: Bool
  @Binding var newFolderName: String?
  @StateObject var folders = FavoriteFolderModel.shared

  @MainActor
  func setFavor(_ operation: TopicFavorRequest.Operation, folderID: String) async {
    let res: Result<TopicFavorResponse, LogicError> = await
      logicCallAsync(.topicFavor(.with {
        $0.topicID = topic.id
        $0.operation = operation
        $0.folderID = folderID
      }))

    if case let .success(response) = res {
      topic.isFavored = response.isFavored
      topic.favorFolderIds = response.folderIds
      HapticUtils.play(type: .success)
    }
  }

  var icon: String {
    topic.isFavored ? "bookmark.fill" : "bookmark"
  }

  @ViewBuilder
  func folderToggle(for folder: FavoriteTopicFolder) -> some View {
    let isFavored = topic.favorFolderIds.contains(folder.id)
    let binding = Binding(
      get: { isFavored },
      set: { _ in
        guard folder.isDefault || checkPlus(.multiFavorite) else { return }
        Task { await setFavor(isFavored ? .delete : .add, folderID: folder.id) }
      }
    )

    Toggle(isOn: binding) {
      Text("\(folder.name)")
      if folder.isDefault {
        Text("Default Folder")
      }
    }
  }

  func favorToNewFolder() async {
    guard let newFolderName else { return }
    guard let folderID = await folders.create(name: newFolderName, haptic: false) else { return }
    await setFavor(.add, folderID: folderID)
  }

  var body: some View {
    Menu {
      if folders.allFolders.isEmpty {
        Text("Loading...").task { await folders.load() }
      } else {
        ForEach(folders.sortedFolders, id: \.id) { folder in
          folderToggle(for: folder)
        }
        Divider()
        Button(action: { newFolderName = ""; showingCreateFolderAlert = true }) {
          Label("New Folder...", systemImage: "folder.badge.plus")
        }
      }
    } label: {
      Label("Mark as Favorite", systemImage: icon)
    }
    .menuActionDismissBehavior(topic.isFavored ? .disabled : .automatic)
    .onChange(of: showingCreateFolderAlert) {
      if $0 == true, $1 == false, newFolderName != nil {
        Task { await favorToNewFolder() }
      }
    }
  }
}

enum TopicResumeFrom: String {
  case none
  case last
  case highest
}

struct TopicDetailsView: View {
  @Namespace var transition

  typealias DataSource = PagingDataSource<TopicDetailsResponse, Post>

  @Binding var topic: Topic

  @Environment(\.enableAuthorOnly) var enableAuthorOnly
  @EnvironmentObject var viewingImage: ViewingImageModel
  @EnvironmentObject.Optional var postReply: PostReplyModel?

  @StateObject var dataSource: DataSource
  @StateObject var action = TopicDetailsActionModel()
  @StateObject var votes = VotesModel()
  @StateObject var prefs = PreferencesStorage.shared
  @StateObject var users = UsersModel.shared
  @StateObject var alert = ToastModel.editorAlert

  let onlyPost: (id: PostId?, atPage: Int?)
  let forceLocalMode: Bool
  let previewMode: Bool

  @State var showJumpSelector = false
  @State var floorToJump: Int?
  @State var postIdToJump: PostId?
  var currentViewingFloor = CurrentViewingFloor()

  @State var showingCreateFolderAlert = false
  @State var newFolderName: String?

  var isFavored: Bool {
    topic.isFavored
  }

  var localMode: Bool {
    forceLocalMode || (dataSource.latestResponse?.isLocalCache == true)
  }

  var mock: Bool {
    topic.id.isMNGAMockID
  }

  static func build(id: String, fav: String? = nil) -> some View {
    build(topic: .with {
      $0.id = id
      if let fav {
        $0.fav = fav
      }
    })
  }

  static func build(onlyPost: (id: PostId, atPage: Int?)) -> some View {
    let topic = Topic.with { $0.id = onlyPost.id.tid }
    return Self.build(topic: topic, onlyPost: onlyPost)
  }

  static func build(
    topicBinding: Binding<Topic>,
    localMode: Bool = false,
    previewMode: Bool = false,
    onlyPost: (id: PostId?, atPage: Int?) = (nil, nil),
    jumpToPost: (id: PostId?, atPage: Int?) = (nil, nil),
  ) -> some View {
    let topic = topicBinding.wrappedValue

    var initialPage = jumpToPost.atPage ?? 1
    var initialFloor: Int?

    // Resume reading progress
    if onlyPost.id == nil, jumpToPost.id == nil, !localMode {
      switch PreferencesStorage.shared.resumeTopicFrom {
      case .none:
        break
      case .last:
        if topic.hasLastViewingFloor, topic.lastViewingFloor >= 3 {
          initialFloor = Int(topic.lastViewingFloor) + 1
        }
      case .highest:
        if topic.hasHighestViewedFloor, topic.highestViewedFloor >= 3 {
          initialFloor = Int(topic.highestViewedFloor) + 1
        }
      }
      if let initialFloor {
        initialPage = (initialFloor + Constants.postPerPage) / Constants.postPerPage
      }
    }

    let dataSource = DataSource(
      buildRequest: { page in
        .topicDetails(TopicDetailsRequest.with {
          $0.webApiStrategy = onlyPost.id == nil ? PreferencesStorage.shared.topicDetailsWebApiStrategy : .disabled
          $0.topicID = topic.id
          if topic.hasFav { $0.fav = topic.fav }
          if let pid = onlyPost.id?.pid { $0.postID = pid }
          $0.localCache = localMode
          $0.page = UInt32(page)
        })
      },
      onResponse: { response in
        if let msg = response.cacheLoadedMessage {
          ToastModel.showAuto(.cacheLoaded(msg))
        }
        let items = response.replies
        let pages = response.pages
        response.inPlaceUsers.forEach(UsersModel.shared.add(user:))
        return (items, Int(pages))
      },
      id: \.floor.description,
      finishOnError: localMode,
      initialPage: initialPage
    )

    return Self(
      topic: topicBinding,
      dataSource: dataSource,
      onlyPost: onlyPost,
      forceLocalMode: localMode,
      previewMode: previewMode,
      floorToJump: initialFloor,
      postIdToJump: jumpToPost.id
    )
    .environment(\.enableAuthorOnly, !localMode)
  }

  static func build(
    topic: Topic,
    localMode: Bool = false,
    onlyPost: (id: PostId?, atPage: Int?) = (nil, nil),
    jumpToPost: (id: PostId?, atPage: Int?) = (nil, nil)
  ) -> some View {
    StaticTopicDetailsView(topic: topic) { binding in
      build(topicBinding: binding, localMode: localMode, onlyPost: onlyPost, jumpToPost: jumpToPost)
    }
  }

  static func build(topic: Topic, only author: AuthorOnly) -> some View {
    let dataSource = DataSource(
      buildRequest: { page in
        .topicDetails(TopicDetailsRequest.with {
          $0.webApiStrategy = .disabled
          $0.topicID = topic.id
          if topic.hasFav { $0.fav = topic.fav }
          $0.page = UInt32(page)
          switch author {
          case let .uid(id):
            $0.authorID = id
          case let .anonymous(id):
            if let id { $0.postID = id.pid }
            $0.anonymousAuthorOnly = true
          }
        })
      },
      onResponse: { response in
        let items = response.replies
        let pages = response.pages
        return (items, Int(pages))
      },
      id: \.floor.description
    )

    return StaticTopicDetailsView(topic: topic) { binding in
      Self(topic: binding, dataSource: dataSource, onlyPost: (nil, nil), forceLocalMode: false, previewMode: false)
        .environment(\.enableAuthorOnly, false)
    }
  }

  private var first: Post? {
    if let first = dataSource.items.min(by: { $0.floor < $1.floor }), first.id.pid == "0" {
      first
    } else {
      nil
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
    Group {
      if dataSource.isLoading {
        ProgressView()
      }
    }.animation(.easeInOut, value: dataSource.isLoading)
  }

  @ViewBuilder
  var replyButton: some View {
    if !mock, onlyPost.id == nil, postReply != nil {
      Button(action: { doReplyTopic() }) {
        Label("Reply", systemImage: "arrowshape.turn.up.left")
      }
    }
  }

  @ViewBuilder
  var favoriteMenu: some View {
    if !mock {
      TopicFavorMenuView(
        topic: $topic,
        showingCreateFolderAlert: $showingCreateFolderAlert.withPlusCheck(.multiFavorite),
        newFolderName: $newFolderName
      )
    }
  }

  @ViewBuilder
  var jumpButton: some View {
    if !mock, onlyPost.id == nil {
      Button(action: { withPlusCheck(.jump) { showJumpSelector = true } }) {
        Label("Jump to...", systemImage: "arrow.up.arrow.down")
      }
    }
  }

  var debugID: String {
    var id = "#\(topic.id)"
    if topic.hasFav, topic.fav != "" {
      id += " @\(topic.fav)"
    }
    if let apiUsed = dataSource.latestResponse?.apiUsed, !apiUsed.isEmpty {
      id += " (\(apiUsed.uppercased()))"
    }
    return id
  }

  @ViewBuilder
  var moreMenu: some View {
    Menu {
      Section(debugID) {
        if enableAuthorOnly {
          Button(action: { withPlusCheck(.authorOnly) {
            action.navigateToAuthorOnly =
              topic.authorName.isAnonymous ? .anonymous(nil) : .uid(topic.authorID)
          } }) {
            Label("Author Only", systemImage: "person")
          }
        }
        if !localMode {
          Button(action: { action.navigateToLocalMode = true }) {
            Label("View Cached Topic", systemImage: "clock")
          }
        }
      }

      ShareLinksView(navigationID: topic.navID, others: {})

      Section {
        favoriteMenu

        if let atForum {
          Button(action: { action.navigateToForum = atForum }) {
            Label("Goto Forum", systemImage: "list.triangle")
            Text("\(atForum.name)")
          }
        }
      }
    } label: {
      Label("More", systemImage: "ellipsis".maybeCircledSymbol)
    }
  }

  @ViewBuilder
  var seeFullTopicButton: some View {
    if onlyPost.id != nil, !topic.id.isEmpty {
      let view = TopicDetailsView.build(topicBinding: $topic, jumpToPost: onlyPost).eraseToAnyView()
      Button(action: { action.navigateToView = view }) {
        Text("Goto Topic")
      }
    }
  }

  @ViewBuilder
  var menu: some View {
    if onlyPost.id == nil {
      moreMenu
    }
  }

  @ViewBuilder
  var mayLoadBackButton: some View {
    if let prevPage = dataSource.firstLoadedPage?.advanced(by: -1), prevPage >= 1,
       let currFirst = dataSource.items.min(by: { $0.floor < $1.floor })
    {
      Button(action: {
        action.scrollToFloor = Int(currFirst.floor) // scroll to first for fixing scroll position
        dataSource.reload(page: prevPage, evenIfNotLoaded: true) {
          guard let floor = dataSource.itemsAtPage(prevPage).map(\.floor).max() else { return }
          DispatchQueue.main.async { action.scrollToFloor = Int(floor) } // scroll to last of prev page
        }
      }) {
        Label("Load Page \(prevPage)", systemImage: "arrow.counterclockwise")
      }.disabled(dataSource.isLoading)
    }
  }

  @ViewBuilder
  func buildRow(post: Post, withId: Bool = true) -> some View {
    let row = PostRowView.build(post: post, isAuthor: post.authorID == topic.authorID, vote: votes.binding(for: post))

    if withId {
      row.id(post)
    } else {
      row
    }
  }

  @State var firstFloorExpanded = true

  @ViewBuilder
  var headerSectionInner: some View {
    TopicSubjectView(topic: topic, lineLimit: nil)
      .fixedSize(horizontal: false, vertical: true)

    if let first, firstFloorExpanded {
      buildRow(post: first)
    } else if previewMode, dataSource.isLoading {
      LoadingRowView(high: true)
    }
  }

  @ViewBuilder
  var headerSection: some View {
    Section {
      headerSectionInner
    } header: {
      if previewMode || first == nil {
        Text("Topic")
      } else {
        CollapsibleSectionHeader(title: "Topic", isExpanded: $firstFloorExpanded)
      }
    }
  }

  @State var hotRepliesExpanded = true

  @ViewBuilder
  var hotRepliesSection: some View {
    if let hotReplies = first?.hotReplies, !hotReplies.isEmpty {
      Section(isExpanded: $hotRepliesExpanded) {
        ForEach(hotReplies, id: \.id.pid) { post in
          buildRow(post: post, withId: false)
        }
      } header: {
        if previewMode {
          Text("Hot Replies")
        } else {
          CollapsibleSectionHeader(title: "Hot Replies", isExpanded: $hotRepliesExpanded)
        }
      }
    }
  }

  @ViewBuilder
  var allRepliesSection: some View {
    if shouldShowReplies {
      Section("Replies") {
        mayLoadBackButton
        ForEach(dataSource.pagedItems, id: \.page) { pair in
          let items = pair.items.filter { $0.id != first?.id }
          ForEach(items, id: \.id.pid) { post in
            buildRow(post: post)
              .onAppear {
                currentViewingFloor.appear(Int(post.floor))
                dataSource.loadMoreIfNeeded(currentItem: post)
              }
              .onDisappear { currentViewingFloor.disappear(Int(post.floor)) }
          }
        }
      }
    }
  }

  private var shouldShowTailSection: Bool {
    onlyPost.id == nil && !dataSource.isInitialLoading
  }

  private var shouldShowTailLoadingRow: Bool {
    guard shouldShowTailSection else { return false }
    if prefs.usePaginatedDetails, onlyPost.id == nil, dataSource.nextPage != nil {
      return false
    }
    return dataSource.isLoading
  }

  private var shouldShowRefreshLastPageButton: Bool {
    guard shouldShowTailSection else { return false }
    return !dataSource.isLoading && !dataSource.hasMore && dataSource.latestResponse != nil
  }

  @ViewBuilder
  var tailSection: some View {
    if shouldShowTailLoadingRow {
      Section { LoadingRowView() }
    } else if shouldShowRefreshLastPageButton {
      Section {
        Button(action: { refreshLastPage() }) {
          Label("Refresh Last Page", systemImage: "arrow.clockwise")
        }
      }
    }
  }

  @ViewBuilder
  var listMain: some View {
    List {
      headerSection
      hotRepliesSection
      allRepliesSection
      tailSection
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
              .onAppear { currentViewingFloor.appear(Int(post.floor)) }
              .onDisappear { currentViewingFloor.disappear(Int(post.floor)) }
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
        }.id("page\(nextPage)")
      }
    }
  }

  @ViewBuilder
  var paginatedMain: some View {
    List {
      headerSection
      hotRepliesSection
      paginatedAllRepliesSectionsNew
      tailSection
    }
  }

  var titles: (String?, String?) {
    var titles: [String] = []

    if !topic.subject.content.isEmpty {
      titles.append(topic.subject.content)
    }

    let subTitle: String? = if localMode {
      "Cached Topic".localized
    } else if !enableAuthorOnly {
      "Author Only".localized
    } else if onlyPost.id != nil {
      "Reply".localized
    } else {
      nil
    }
    if let subTitle {
      titles.append(subTitle)
    }

    if let atForum {
      titles.append(atForum.name)
    }

    return (titles.first, titles.dropFirst().first)
  }

  var title: String? { titles.0 }
  var subtitle: String? { titles.1 }

  @ViewBuilder
  var loadFirstPageButton: some View {
    if let page = dataSource.firstLoadedPage, page >= 2 {
      Button(action: { dataSource.loadFromPage = 1; floorToJump = 0 }) {
        Label("Load First Page", systemImage: "arrow.up.to.line")
      }
    }
  }

  @ToolbarContentBuilder
  var toolbar: some ToolbarContent {
    FullScreenButtonToolbarItem()
    ToolbarItem(placement: .navigationBarTrailing) { progress }
      .maybeSharedBackgroundVisibility(.hidden)
    MaybeToolbarSpacer(.fixed, placement: .navigationBarTrailing)
    NotificationToolbarItem(placement: .navigationBarTrailing)
    ToolbarItem(placement: .navigationBarTrailing) { menu }

    ToolbarItem(placement: .bottomBar) { jumpButton }
      .maybeMatchedTransitionSource(id: "jump", in: transition)
    ToolbarItem(placement: .bottomBar) { loadFirstPageButton }
    MaybeToolbarSpacer(placement: .bottomBar)
    ToolbarItemGroup(placement: .bottomBar) {
      // They won't show simultaneously.
      replyButton
      seeFullTopicButton
    }
  }

  @ViewBuilder
  var xmlParseErrorMain: some View {
    List {
      headerSection
      Section {
        Button(action: { dataSource.refresh(animated: true) }) {
          Label("Refresh", systemImage: "arrow.clockwise")
        }
        Button(action: { openInBrowser() }) {
          Label("Open in Browser", systemImage: "safari")
        }
      }
    }
  }

  @State var jumpSelectorMode = TopicJumpSelectorView.Mode.floor

  @ViewBuilder
  var jumpSelector: some View {
    TopicJumpSelectorView(
      maxFloor: maxFloor,
      mode: $jumpSelectorMode,
      initialFloor: currentViewingFloor.currentLowest ?? 0,
      floorToJump: $floorToJump,
      pageToJump: $dataSource.loadFromPage
    )
    .maybeNavigationTransition(.zoom(sourceID: "jump", in: transition))
    .presentationDetents([.medium])
  }

  @ViewBuilder
  var main: some View {
    ScrollViewReader { proxy in
      Group {
        if dataSource.latestResponse == nil, let error = dataSource.latestError, error.isXMLParseError {
          xmlParseErrorMain
        } else if prefs.usePaginatedDetails, onlyPost.id == nil {
          paginatedMain
        } else {
          listMain
        }
      }.onReceive(action.$scrollToFloor) { floor in
        guard let floor else { return }
        let item = dataSource.items.first { $0.floor == UInt32(floor) }
        withAnimation { proxy.scrollTo(item, anchor: .top) }
      }.onReceive(action.$scrollToPid) { pid in
        guard let pid else { return }
        let item = dataSource.items.first { $0.id.pid == pid }
        withAnimation { proxy.scrollTo(item, anchor: .top) }
      }
    }
    // Action Navigation
    .withTopicDetailsAction(action: action)
    .navigationDestination(item: $action.showingReplyChain) {
      PostReplyChainView(baseDataSource: dataSource, votes: votes, chain: $0)
    }
    .navigationDestination(item: $action.navigateToAuthorOnly) {
      TopicDetailsView.build(topic: topic, only: $0)
    }
    .navigationDestination(isPresented: $action.navigateToLocalMode) {
      TopicDetailsView.build(topic: topic, localMode: true)
    }
    // Action Navigation End
    .onReceive(dataSource.$lastRefreshTime) { _ in mayScrollToJumpFloor() }
    .sheet(isPresented: $showJumpSelector) { jumpSelector }
    // Favorite to new folder
    .alert("Add to New Folder", isPresented: $showingCreateFolderAlert) {
      TextField("Unnamed Folder", text: $newFolderName.withDefaultValue(""))
      Button("Done", role: .maybeConfirm) {}
      Button("Cancel", role: .cancel) { newFolderName = nil }
    }
    .navigationTitle(title ?? "")
    .maybeNavigationSubtitle(subtitle ?? "")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar { toolbar }
    .refreshable(dataSource: dataSource)
    .toolbarRole(.editor) // make title left aligned
    .onChange(of: postReply?.sent) { reloadPageAfter(sent: $1) }
    .onChange(of: dataSource.latestError) { onError(e: $1) }
    .onDisappearOrInactive { syncTopicProgress() }
    .userActivity(Constants.Activity.openTopic) { $0.webpageURL = topic.navID.webpageURL }
  }

  var body: some View {
    Group {
      if previewMode {
        // We don't want side effects when previewing, thus use `listMain` instead of `main`.
        listMain
      } else {
        main
      }
    }
    .mayGroupedListStyle()
    .onAppear { dataSource.initialLoad() }
    .onChange(of: dataSource.latestResponse) { updateTopicOnNewResponse(response: $1) }
  }

  var maxFloor: Int {
    Int((dataSource.latestResponse?.topic ?? topic).repliesNum)
  }

  func mayScrollToJumpFloor() {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      withAnimation {
        if let floor = floorToJump {
          action.scrollToFloor = floor
          floorToJump = nil
        } else if let pid = postIdToJump?.pid {
          action.scrollToPid = pid
          postIdToJump = nil
        }
      }
    }
  }

  func syncTopicProgress() {
    guard !topic.id.isEmpty, !mock else { return }
    let seen = currentViewingFloor.highestSeen.map { UInt32($0) } ?? 0
    let highest = max(topic.highestViewedFloor, seen)
    let current = currentViewingFloor.currentLowest.map { UInt32($0) } ?? 0

    let _: UpdateTopicProgressResponse? = try? logicCall(.updateTopicProgress(.with {
      $0.topicID = topic.id
      $0.highestFloor = highest
      $0.currentFloor = current
    }))
    topic.highestViewedFloor = highest
    topic.lastViewingFloor = current
  }

  func doReplyTopic() {
    postReply?.show(action: .with {
      $0.operation = .reply
      $0.forumID = .with { f in
        f.fid = topic.fid
      }
      $0.postID = .with {
        $0.tid = topic.id
        $0.pid = "0"
      }
    }, pageToReload: .last)
  }

  func reloadPageAfter(sent: PostReplyModel.Context?) {
    guard let sent else { return }

    switch sent.task.pageToReload {
    case let .exact(page):
      dataSource.reload(page: page, evenIfNotLoaded: false)
    case .last:
      dataSource.reloadLastPages(evenIfNotLoaded: false)
    case .none:
      break
    }
  }

  func refreshLastPage() {
    dataSource.reloadLastPages(evenIfNotLoaded: true)
    HapticUtils.play(type: .success)
  }

  func updateTopicOnNewResponse(response: TopicDetailsResponse?) {
    guard let response else { return }
    let newTopic = response.topic

    if topic.id.isEmpty { // for onlyPost, we may not have the topic id initially
      topic.id = newTopic.id
    }
    if newTopic.hasParentForum {
      topic.parentForum = newTopic.parentForum
    }
    topic.authorID = newTopic.authorID
    topic.subject = newTopic.subject

    // Following fields will be actually updated by logic.
    // But we still need to update them here to reflect the new state, even without
    // fetching again. For example, user may navigate to this topic again without refreshing.
    topic.repliesNumLastVisit = newTopic.repliesNum
    topic.highestViewedFloor = newTopic.highestViewedFloor
    topic.lastViewingFloor = newTopic.lastViewingFloor

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

      if let hotReplies = first?.hotReplies, !hotReplies.isEmpty {
        Text("Hot Replies")
          .font(.footnote)
          .foregroundColor(.secondary)
        ForEach(hotReplies, id: \.id.pid) { post in
          Divider()
          buildRow(post: post, withId: false)
        }
      } else {
        let latestReplies = dataSource.sortedItems(by: \.floor).dropFirst().prefix(5)

        if !latestReplies.isEmpty {
          Text("Replies")
            .font(.footnote)
            .foregroundColor(.secondary)
          ForEach(latestReplies, id: \.id.pid) { post in
            Divider()
            buildRow(post: post, withId: false)
          }
        }
      }
    }
    .padding()
    .fixedSize(horizontal: false, vertical: true)
    .frame(width: Screen.main.bounds.size.width)
    .background(.secondarySystemGroupedBackground)
  }

  func openInBrowser() {
    if let url = topic.navID.webpageURL {
      OpenURLModel.shared.open(url: url)
    }
  }

  func onError(e: LogicError?) {
    guard let e else { return }
    if e.isXMLParseError, prefs.autoOpenInBrowserWhenBanned {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
        openInBrowser()
      }
    }
  }
}

struct TopicDetailsView_Preview: PreviewProvider {
  static var previews: some View {
    AuthedPreview {
      NavigationView {
        TopicDetailsView.build(topic: Topic.with {
          $0.id = "45055554" // "27555218"
          $0.subject = .with { s in
            s.content = "Topic Title"
          }
        })
      }
    }
  }
}
