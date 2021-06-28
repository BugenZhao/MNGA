//
//  TopicListView.swift
//  NGA
//
//  Created by Bugen Zhao on 6/28/21.
//

import Foundation
import SwiftUI

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
      Text(subforum.name)
    } .onChange(of: selected, perform: { value in
      self.action(value)
    })
  }
}

struct TopicListView: View {
  let forumID: String

  @StateObject var dataSource: PagingDataSource<TopicListResponse, Topic>

  init(forumID: String = "-7") {
    self.forumID = forumID

    let dataSource = PagingDataSource<TopicListResponse, Topic>(
      buildRequest: { page in
        return .topicList(TopicListRequest.with {
          $0.forumID = forumID
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
    VStack {
      if dataSource.items.isEmpty {
        ProgressView()
      } else {
        let list = List {
          ForEach(dataSource.items, id: \.id) { topic in
            let destination = NavigationLazyView(TopicDetailsView(topic: topic))

            NavigationLink(destination: destination) {
              TopicView(topic: topic)
                .onAppear { dataSource.loadMoreIfNeeded(currentItem: topic) }
            }
          }
        }
        #if os(iOS)
          list.listStyle(InsetGroupedListStyle())
        #else
          list
        #endif
      }
    }
      .navigationTitle(title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
      ToolbarItem(placement: .navigationBarTrailing) {
        Menu {
          if let subforums = dataSource.latestResponse?.subforums {
            Menu {
              ForEach(subforums.filter { $0.filterable }, id: \.id) { subforum in
                SubforumFilterToggleView(subforum: subforum) { v in
                  setSubforumFilter(show: v, subforum: subforum)
                }
              }
            } label: {
              Label("Subforums", systemImage: "line.horizontal.3.decrease.circle")
            }
          }
          Section {
            Button(action: { dataSource.refresh(clear: true) }) {
              Label("Refresh", systemImage: "arrow.clockwise")
            }
            Text("#\(forumID) " + (dataSource.latestResponse?.forum.name ?? ""))
          }
        } label: {
          Label("Menu", systemImage: "ellipsis.circle")
        }
      }
    }
  }

  var title: String {
    dataSource.latestResponse?.forum.name ?? "Forum #\(forumID)"
  }

  func setSubforumFilter(show: Bool, subforum: Subforum) {
    logicCallAsync(.subforumFilter(.with {
      $0.operation = show ? .show : .block
      $0.forumID = forumID
      $0.subforumFilterID = subforum.filterID
    })) { (response: SubforumFilterResponse) in
      dataSource.refresh(clear: true)
    }
  }
}

struct TopicListView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      TopicListView()
    }
  }
}
