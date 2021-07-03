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

struct SubforumFilterToggleView: View {
  let subforum: Subforum
  let action: (_ newSelected: Bool) -> Void

  @State var selected: Bool

  init(subforum: Subforum, action: @escaping (_ newSelected: Bool) -> Void) {
    self.subforum = subforum
    self._selected = State(wrappedValue: subforum.selected)
    self.action = action
  }

  var body: some View {
    Toggle(isOn: $selected) {
      Text(subforum.forum.name)
    } .onChange(of: selected, perform: { value in
      self.action(value)
    })
  }
}

struct TopicListView: View {
  let forum: Forum

  @StateObject var dataSource: PagingDataSource<TopicListResponse, Topic>

  init(forum: Forum) {
    self.forum = forum

    let dataSource = PagingDataSource<TopicListResponse, Topic>(
      buildRequest: { page in
        return .topicList(TopicListRequest.with {
          switch forum.id! {
          case .fid(let fid):
            $0.fid = fid
          case .stid(let stid):
            $0.stid = stid
          }
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

  var body: some View {
    let inner = VStack {
      if dataSource.items.isEmpty {
        ProgressView()
      } else {
        let list = List {
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
          list
            .listStyle(GroupedListStyle())
            .pullToRefresh(isShowing: $dataSource.isLoading) {
            dataSource.refresh(clear: false)
          }
        #else
          list
        #endif
      }
    }
      .navigationTitle(title)
      .toolbar {

//      ToolbarItem {
//        Menu {
//          if let subforums = dataSource.latestResponse?.subforums,
//            !subforums.isEmpty {
//            Menu {
//              ForEach(subforums.filter { $0.filterable }, id: \.id) { subforum in
//                SubforumFilterToggleView(subforum: subforum) { v in
//                  setSubforumFilter(show: v, subforum: subforum)
//                }
//              }
//            } label: {
//              Label("Subforums", systemImage: "line.horizontal.3.decrease.circle")
//            }
//          }
//          Section {
//            #if os(macOS)
//              Button(action: { dataSource.refresh(clear: true) }) {
//                Label("Refresh", systemImage: "arrow.clockwise")
//              }
//            #endif
//            Label("#\(forum.id) " + (dataSource.latestResponse?.forum.name ?? ""), systemImage: "number")
//          }
//        } label: {
//          Label("Menu", systemImage: "ellipsis.circle")
//            .imageScale(.large)
//        }
//      }
      ToolbarItem {
        if let subforums = dataSource.latestResponse?.subforums,
          !subforums.isEmpty {
          NavigationLink(destination: SubforumListView(subforums: subforums)) {
            Label("Subforums", systemImage: "line.horizontal.3.decrease.circle")
          }
        }
      }
    } .onFirstAppear { dataSource.initialLoad() }

    #if os(iOS)
      inner
//        .navigationBarTitleDisplayMode(.inline)
    #elseif os(macOS)
      inner
    #endif
  }

  var title: String {
    forum.name
  }

  func setSubforumFilter(show: Bool, subforum: Subforum) {
    logicCallAsync(.subforumFilter(.with {
      $0.operation = show ? .show : .block
      $0.forumID = forum.fid
      $0.subforumFilterID = subforum.filterID
    })) { (response: SubforumFilterResponse) in
      dataSource.refresh(clear: true)
    }
  }
}

struct TopicListView_Previews: PreviewProvider {
  static var previews: some View {
    let defaultForum = Forum.with {
      $0.fid = "-7"
      $0.name = "大漩涡"
      $0.iconURL = "http://img4.nga.178.com/ngabbs/nga_classic/f/app/-7.png"
    }

    let genshinForum = Forum.with {
      $0.fid = "650"
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
