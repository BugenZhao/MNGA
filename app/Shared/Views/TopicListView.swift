//
//  TopicListView.swift
//  NGA
//
//  Created by Bugen Zhao on 6/28/21.
//

import Foundation
import SwiftUI
import SwiftUIRefresh
import SDWebImageSwiftUI

struct TopicListView: View {
  let forum: Forum

  @StateObject var dataSource: PagingDataSource<TopicListResponse, Topic>

  @State var currentShowingSubforum: Forum? = nil
  @State var showingSubforumsModal = false
  @State var showingHotTopics = false

  init(forum: Forum) {
    self.forum = forum

    let dataSource = PagingDataSource<TopicListResponse, Topic>(
      buildRequest: { page in
        return .topicList(TopicListRequest.with {
          $0.id = forum.id
          $0.page = UInt32(page)
        })
      },
      onResponse: { response in
        let items = response.topics
        let pages = response.pages
        return (items, Int(pages))
      },
      id: \.id
    )
    self._dataSource = StateObject(wrappedValue: dataSource)
  }

  @ViewBuilder
  var moreMenu: some View {
    Menu {
      Section {
        Button(action: { showingHotTopics = true }) {
          Label("Hot Topics", systemImage: "flame")
        }
        if let subforums = dataSource.latestResponse?.subforums,
          !subforums.isEmpty {
          Button(action: { showingSubforumsModal = true }) {
            Label("Subforums", systemImage: "line.horizontal.3.decrease.circle")
          }
        }
      }

      Section {
        #if os(macOS)
          Button(action: { dataSource.refresh(clear: true) }) {
            Label("Refresh", systemImage: "arrow.clockwise")
          }
        #endif
        Label(forum.idDescription + " " + (dataSource.latestResponse?.forum.name ?? ""), systemImage: "number")
      }
    } label: {
      Label("More", systemImage: "ellipsis.circle")
        .imageScale(.large)
    }
  }

  @ViewBuilder
  var subforumsModal: some View {
    if let subforums = dataSource.latestResponse?.subforums, !subforums.isEmpty {
      NavigationView {
        SubforumListView(
          forum: forum,
          subforums: subforums,
          refresh: { dataSource.refresh() },
          onNavigateToForum: {
            self.showingSubforumsModal = false
            self.currentShowingSubforum = $0
          }
        )
      }
    }
  }

  @ViewBuilder
  var subforum: some View {
    if let forum = self.currentShowingSubforum {
      let destination = TopicListView(forum: forum)
      NavigationLink(destination: destination, isActive: $currentShowingSubforum.isNotNil()) { }
    }
  }

  @ViewBuilder
  var hotTopics: some View {
    let destination = HotTopicListView(forum: forum)
    NavigationLink(destination: destination, isActive: $showingHotTopics) { }
  }

  var body: some View {
    Group {
      if dataSource.items.isEmpty {
        ProgressView()
      } else {
        List {
          Section(header: Text("Latest Topics")) {
            ForEach(dataSource.items, id: \.id) { topic in
              NavigationLink(destination: TopicDetailsView(topic: topic)) {
                TopicView(topic: topic)
                  .onAppear { dataSource.loadMoreIfNeeded(currentItem: topic) }
              }
            }
          }
        }
        #if os(iOS)
          .listStyle(GroupedListStyle())
          .pullToRefresh(isShowing: $dataSource.isLoading) { dataSource.refresh() }
        #endif
      }
    }
      .sheet(isPresented: $showingSubforumsModal) { subforumsModal }
      .background { subforum; hotTopics }
      .navigationTitle(forum.name)
      .toolbar {
      ToolbarItem(placement: .navigationBarLeading) { Text("") } // fix back button bug
      ToolbarItem(placement: .navigationBarTrailing) { moreMenu }
    }
      .onFirstAppear { dataSource.initialLoad() }
  }
}

struct TopicListView_Previews: PreviewProvider {
  static var previews: some View {
    let defaultForum = Forum.with {
      $0.id = .with { i in i.fid = "-7" }
      $0.name = "大漩涡"
      $0.iconURL = "http://img4.nga.178.com/ngabbs/nga_classic/f/app/-7.png"
    }

    let genshinForum = Forum.with {
      $0.id = .with { i in i.fid = "650" }
      $0.name = "原神"
      $0.iconURL = "http://img4.nga.178.com/ngabbs/nga_classic/f/app/650.png"
    }

    AuthedPreview {
      NavigationView {
        TopicListView(forum: genshinForum)
      }
    }
  }
}
