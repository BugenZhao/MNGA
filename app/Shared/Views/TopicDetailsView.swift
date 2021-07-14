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

class PostScrollModel: ObservableObject {
  @Published var pid: String? = nil
}

struct TopicDetailsView: View {
  let topic: Topic

  @StateObject var dataSource: PagingDataSource<TopicDetailsResponse, Post>
  @StateObject var postScroll = PostScrollModel()
  @StateObject var votes = VotesModel()

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

    return Self.init(topic: topic, dataSource: dataSource)
  }

  private var first: Post? { dataSource.items.first }

  @ViewBuilder
  var moreMenu: some View {
    Menu {
      Section {
        Label("#" + topic.id, systemImage: "number")
        if topic.hasFav {
          Label(topic.fav, systemImage: "heart")
        }
      }
    } label: {
      Label("More", systemImage: "ellipsis.circle")
        .imageScale(.large)
    }
  }

  @ViewBuilder
  func buildRow(post: Post, withId: Bool = true) -> some View {
    let row = PostRowView(post: post, vote: votes.binding(for: post))
    if withId { row.id(post.id.pid) }
    else { row }
  }

  @ViewBuilder
  var headerSection: some View {
    Section(header: HStack {
      Text("Topic")
      Spacer()
      if dataSource.isLoading { ProgressView() }
    }) {
      TopicSubjectView(topic: topic, lineLimit: nil)
      if let first = self.first {
        buildRow(post: first)
      }
    }
  }

  @ViewBuilder
  var hotRepliesSection: some View {
    if let hotReplies = self.first?.hostReplies, !hotReplies.isEmpty {
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
        ForEach(dataSource.items.dropFirst(), id: \.id.pid) { post in
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
      .navigationTitle(topic.subjectContent)
      .modifier(SingleItemToolbarModifier { moreMenu })
      .onAppear { dataSource.initialLoad() }
    #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
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
}


struct TopicDetailsView_Preview: PreviewProvider {
  static var previews: some View {
    AuthedPreview {
      NavigationView {
        TopicDetailsView.build(topic: Topic.with {
          $0.id = "27555218"
          $0.subjectContent = "Topic Title"
        })
      }
    }
  }
}
