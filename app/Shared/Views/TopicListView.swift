//
//  TopicListView.swift
//  NGA
//
//  Created by Bugen Zhao on 6/28/21.
//

import Foundation
import SDWebImageSwiftUI
import SwiftUI

struct TopicListView: View {
  typealias DataSource = PagingDataSource<TopicListResponse, Topic>

  @State var forum: Forum

  @EnvironmentObject var postReply: PostReplyModel

  @StateObject var dataSourceLastPost: DataSource
  @StateObject var dataSourcePostDate: DataSource
  @StateObject var favoriteForums = FavoriteForumsStorage.shared
  @StateObject var searchModel: TopicSearchModel
  @StateObject var prefs = PreferencesStorage.shared

  @State var currentShowingSubforum: Forum? = nil
  @State var showingSubforumsModal = false
  @State var order: TopicListRequest.Order? = nil

  var dataSource: DataSource {
    switch order {
    case .lastPost, .none: dataSourceLastPost
    case .postDate: dataSourcePostDate
    default: fatalError()
    }
  }

  var mock: Bool {
    forum.id.fid.isMNGAMockID
  }

  var itemBindings: Binding<[Topic]> {
    switch order {
    case .lastPost, .none:
      $dataSourceLastPost.items
    case .postDate:
      $dataSourcePostDate.items
    default: fatalError()
    }
  }

  static func build(id: ForumId) -> Self {
    let forum = Forum.with {
      $0.id = id
    }
    return Self.build(forum: forum)
  }

  static func build(forum: Forum) -> Self {
    let dataSourceLastPost = DataSource(
      buildRequest: { page in
        .topicList(TopicListRequest.with {
          $0.id = forum.id
          $0.page = UInt32(page)
          $0.order = .lastPost
        })
      },
      onResponse: { response in
        let items = response.topics
        let pages = response.pages
        return (items, Int(pages))
      },
      id: \.id
    )
    let dataSourcePostDate = DataSource(
      buildRequest: { page in
        .topicList(TopicListRequest.with {
          $0.id = forum.id
          $0.page = UInt32(page)
          $0.order = .postDate
        })
      },
      onResponse: { response in
        let items = response.topics
        let pages = response.pages
        return (items, Int(pages))
      },
      id: \.id
    )
    return Self(
      forum: forum,
      dataSourceLastPost: dataSourceLastPost,
      dataSourcePostDate: dataSourcePostDate,
      searchModel: TopicSearchModel(id: forum.id)
    )
  }

  func newTopic() {
    postReply.show(action: .with {
      $0.operation = .new
      $0.forumID = forum.id
    }, pageToReload: nil)
  }

  var isFavorite: Bool {
    favoriteForums.isFavorite(id: forum.id)
  }

  var toppedTopicID: String? {
    let id = dataSource.latestResponse?.forum.toppedTopicID ?? forum.toppedTopicID
    return id.isEmpty ? nil : id
  }

  @ViewBuilder
  var newTopicButton: some View {
    if !mock {
      Button(action: { newTopic() }) {
        Label("New Topic", systemImage: "square.and.pencil")
      }
    }
  }

  @ViewBuilder
  var subforumButton: some View {
    Button(action: { showingSubforumsModal = true }) {
      Label("Subforums", systemImage: "list.triangle")
    }
  }

  var debugName: String {
    forum.idDescription + " " + (dataSource.latestResponse?.forum.name ?? "")
  }

  @ViewBuilder
  var moreMenu: some View {
    Menu {
      if !mock {
        Section(debugName) {
          Menu {
            Picker(selection: $order, label: Text("Order")) {
              ForEach(TopicListRequest.Order.allCases, id: \.rawValue) { order in
                Label(order.description, systemImage: order.icon)
                  .tag(order as TopicListRequest.Order?)
              }
            }
          } label: {
            Label("Order by", systemImage: (order ?? .lastPost).icon)
          }

          NavigationLink(destination: HotTopicListView.build(forum: forum)) {
            Label("Hot Topics", systemImage: "flame")
          }.isDetailLink(false)
          NavigationLink(destination: RecommendedTopicListView.build(forum: forum)) {
            Label("Recommended Topics", systemImage: "hand.thumbsup")
          }.isDetailLink(false)

          if let topicID = toppedTopicID {
            NavigationLink(destination: TopicDetailsView.build(id: topicID)) {
              Label("Topped Topic", systemImage: "arrow.up.to.line")
            }
          }
        }
      }

      ShareLinksView(navigationID: navID) {}

      Section {
        Button(action: { favoriteForums.toggleFavorite(forum: forum) }) {
          Label(
            isFavorite ? "Remove from Favorites" : "Mark as Favorite",
            systemImage: isFavorite ? "star.slash.fill" : "star"
          )
        }
        #if os(macOS)
          Button(action: { dataSource.refresh() }) {
            Label("Refresh", systemImage: "arrow.clockwise")
          }
        #endif
      }
    } label: {
      Label("More", systemImage: "ellipsis.circle")
        .imageScale(.large)
    }
  }

  @ViewBuilder
  var subforumsModal: some View {
    NavigationView {
      Group {
        if let subforums = dataSource.latestResponse?.subforums {
          SubforumListView(
            forum: forum,
            subforums: subforums,
            refresh: { dataSource.refresh(animated: true) },
            onNavigateToForum: {
              showingSubforumsModal = false
              currentShowingSubforum = $0
            }
          )
        } else {
          ProgressView()
        }
      }.navigationTitle("Subforums of \(forum.name)")
        .navigationBarTitleDisplayMode(.inline)
    }
  }

  @ViewBuilder
  var icon: some View {
    ForumIconView(iconURL: forum.iconURL)
  }

  @ToolbarContentBuilder
  var toolbar: some ToolbarContent {
    #if os(iOS)
      // -- Navigation Bar
      ToolbarItem(placement: .navigationBarTrailing) { icon }
      ToolbarItem(placement: .navigationBarTrailing) { moreMenu }

      // -- Bottom Bar
      ToolbarItem(placement: .bottomBar) { subforumButton }
      ToolbarSpacer(placement: .bottomBar)
      DefaultToolbarItem(kind: .search, placement: .bottomBar)
      ToolbarSpacer(placement: .bottomBar)
      ToolbarItem(placement: .bottomBar) { newTopicButton }
    #elseif os(macOS)
      ToolbarItemGroup {
        newTopicButton
        moreMenu
      }
    #endif
  }

  @ViewBuilder
  var list: some View {
    Group {
      if dataSource.notLoaded {
        ProgressView()
          .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { // hack for search bar animation
              dataSource.initialLoad()
            }
          }
      } else {
        List {
          ForEach(itemBindings, id: \.id) { topic in
            CrossStackNavigationLinkHack(id: topic.w.id, destination: {
              TopicDetailsView.build(topicBinding: topic)
            }) {
              TopicRowView(topic: topic.w, useTopicPostDate: order == .postDate)
            }.onAppear { dataSource.loadMoreIfNeeded(currentItem: topic.w) }
          }
          .id(order)
        }
      }
    }
    .refreshable(dataSource: dataSource, refreshWhenEnterForeground: true)
    .mayGroupedListStyle()
  }

  var body: some View {
    Group {
      if let dataSource = searchModel.dataSource {
        TopicSearchView(dataSource: dataSource)
      } else {
        list
      }
    }
    .searchable(model: searchModel, prompt: "Search Topics".localized, if: !mock)
    .navigationTitleLarge(string: forum.name.localized)
    .sheet(isPresented: $showingSubforumsModal) { subforumsModal.presentationDetents([.medium, .large]) }
    .onChange(of: postReply.sent) { dataSource.reload(page: 1, evenIfNotLoaded: false) }
    .navigationDestination(item: $currentShowingSubforum) { TopicListView.build(forum: $0) }
    .toolbar { toolbar }
    .onChange(of: prefs.defaultTopicListOrder) { if $1 != order { order = $1 } }
    .onAppear { if order == nil { order = prefs.defaultTopicListOrder } }
    .onChange(of: dataSource.latestResponse) { updateForumMeta($1) }
  }

  var navID: NavigationIdentifier {
    .forumID(forum.id)
  }

  func updateForumMeta(_ r: TopicListResponse?) {
    guard let r else { return }
    if forum.name.isEmpty {
      forum.name = r.forum.name
      forum.info = r.forum.info
      forum.iconURL = r.forum.iconURL
    }
  }
}

struct TopicListView_Previews: PreviewProvider {
  static var previews: some View {
    let genshinForum = Forum.with {
      $0.id = .with { i in i.fid = "650" }
      $0.name = "原神"
      $0.iconURL = "http://img4.nga.178.com/ngabbs/nga_classic/f/app/650.png"
    }

    AuthedPreview {
      NavigationView {
        TopicListView.build(forum: genshinForum)
      }
    }
  }
}
