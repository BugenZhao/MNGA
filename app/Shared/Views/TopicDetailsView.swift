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

class PostScrollModel: ObservableObject {
  @Published var pid: String? = nil
}

struct TopicDetailsView: View {
  let topic: Topic

  @EnvironmentObject var activity: ActivityModel

  @StateObject var dataSource: PagingDataSource<TopicDetailsResponse, Post>
  @StateObject var postScroll = PostScrollModel()
  @StateObject var votes = VotesModel()
  @StateObject var postReply = PostReplyModel()

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
        Button(action: { self.activity.put(URL(string: webpageURL)) }) {
          Label("Share", systemImage: "square.and.arrow.up")
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
    PostRowView.build(post: post, vote: votes.binding(for: post))
      .id((withId ? "" : "dummy") + post.id.pid)
  }

  @ViewBuilder
  var headerSection: some View {
    Section(header: HStack {
      Text("Topic")
      Spacer()
      if dataSource.isLoading { ProgressView() }
    }) {
      TopicSubjectView(topic: latestTopic, lineLimit: nil)
      if let first = self.first {
        buildRow(post: first)
      }
    }
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

  var body: some View {
    VStack(alignment: .leading) {
      ScrollViewReader { proxy in
        List {
          headerSection
          hotRepliesSection
          allRepliesSection
        } .environmentObject(postScroll)
          .onReceive(postScroll.$pid) { pid in
          withAnimation { proxy.scrollTo(pid) }
        }
      }
      #if os(iOS)
        .listStyle(GroupedListStyle())
      #endif
    }
      .navigationTitle(latestTopic.subjectContent)
      .modifier(SingleItemToolbarModifier { moreMenu })
      .sheet(isPresented: $postReply.showEditor) { PostEditorView().environmentObject(postReply) }
      .onChange(of: postReply.sent, perform: self.reloadPageAfter(sent:))
      .environmentObject(postReply)
      .onAppear { dataSource.initialLoad() }
    #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
//        .pullToRefresh(isShowing: .constant(dataSource.isRefreshing)) { dataSource.refresh() }
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
    })
  }

  func reloadPageAfter(sent: PostReplyModel.Context?) {
    guard let sent = sent else { return }

    if let page = sent.task.pageToReload {
      dataSource.reload(page: page)
    } else {
      dataSource.reloadLastPages()
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
