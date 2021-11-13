//
//  UserProfileView.swift
//  UserProfileView
//
//  Created by Bugen Zhao on 2021/9/10.
//

import Foundation
import SwiftUI
import SDWebImageSwiftUI

struct UserProfileView: View {
  typealias TopicDataSource = PagingDataSource<UserTopicListResponse, Topic>
  typealias PostDataSource = PagingDataSource<UserPostListResponse, TopicWithLightPost>

  enum Tab: LocalizedStringKey, CaseIterable {
    case topics = "Topics"
    case posts = "Posts"
  }

  let user: User

  @StateObject var topicDataSource: TopicDataSource
  @StateObject var postDataSource: PostDataSource
  @EnvironmentObject var postModel: ShortMessagePostModel

  @State var tab = Tab.topics

  static func build(user: User) -> Self {
    let topicDataSource = TopicDataSource(
      buildRequest: { page in
        return .userTopicList(UserTopicListRequest.with {
          $0.authorID = user.id
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

    let postDataSource = PostDataSource(
      buildRequest: { page in
        return .userPostList(UserPostListRequest.with {
          $0.authorID = user.id
          $0.page = UInt32(page)
        })
      },
      onResponse: { response in
        let items = response.tps
        return (items, Int.max)
      },
      id: \.post.id.description,
      finishOnError: true
    )

    return Self.init(user: user, topicDataSource: topicDataSource, postDataSource: postDataSource)
  }

  var shouldShowList: Bool {
    !user.id.isEmpty && !user.isAnonymous
  }

  @ViewBuilder
  var list: some View {
    switch self.tab {
    case .topics:
      if topicDataSource.notLoaded {
        LoadingRowView()
          .onAppear { topicDataSource.initialLoad() }
      } else {
        Section(header: Text("\(user.name.display)'s Topics")) {
          if topicDataSource.items.isEmpty {
            EmptyRowView()
          } else {
            ForEach($topicDataSource.items, id: \.id) { topic in
              NavigationLink(destination: TopicDetailsView.build(topicBinding: topic)) {
                TopicRowView(topic: topic.w)
              } .onAppear { topicDataSource.loadMoreIfNeeded(currentItem: topic.w) }
            }
          }
        }
      }
    case .posts:
      if postDataSource.notLoaded {
        LoadingRowView()
          .onAppear { postDataSource.initialLoad() }
      } else {
        Section(header: Text("\(user.name.display)'s Posts")) {
          if postDataSource.items.isEmpty {
            EmptyRowView()
          } else {
            ForEach(postDataSource.items, id: \.post.id) { tp in
              NavigationLink(destination: TopicDetailsView.build(topic: tp.topic, onlyPost: (id: tp.post.id, atPage: nil))) {
                TopicPostRowView(topic: tp.topic, post: tp.post)
              } .onAppear { postDataSource.loadMoreIfNeeded(currentItem: tp) }
            }
          }
        }
      }
    }
  }

  @ToolbarContentBuilder
  var toolbar: some ToolbarContent {
    ToolbarItem(placement: .principal) {
      if shouldShowList {
        Picker("Tab", selection: $tab.animation()) {
          ForEach(Tab.allCases, id: \.self) {
            Text($0.rawValue).tag($0)
          }
        } .pickerStyle(SegmentedPickerStyle())
          .frame(maxWidth: 200)
      }
    }

    ToolbarItem(placement: .mayNavigationBarTrailing) {
      Button(action: { self.newShortMessage() }) {
        Label("New Short Message", systemImage: "message")
      }
    }
  }

  var body: some View {
    List {
      Section(header: Text("User Profile")) {
        UserView(user: user, style: .huge)
        if let sig = user.signature, !sig.spans.isEmpty {
          UserSignatureView(content: sig, font: .callout, color: .primary)
        }
      }

      if shouldShowList {
        list
      }
    }
      .toolbarWithFix { toolbar }
      .withTopicDetailsAction() // for signature only
      .mayGroupedListStyle()
      .navigationTitleInline(string: user.name.display)
  }

  func newShortMessage() {
    self.postModel.show(action: .with {
      $0.operation = .newSingleTo
      $0.singleTo = user.name.normal
    })
  }
}
