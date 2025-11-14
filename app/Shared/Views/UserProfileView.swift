//
//  UserProfileView.swift
//  UserProfileView
//
//  Created by Bugen Zhao on 2021/9/10.
//

import Foundation
import SDWebImageSwiftUI
import SwiftUI

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
  @EnvironmentObject var currentUser: CurrentUserModel

  @StateObject var blockWords = BlockWordsStorage.shared

  @State var tab = Tab.topics

  var isMyself: Bool {
    user.id == currentUser.user?.id
  }

  static func build(user: User) -> Self {
    let topicDataSource = TopicDataSource(
      buildRequest: { page in
        .userTopicList(UserTopicListRequest.with {
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
        .userPostList(UserPostListRequest.with {
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

    return Self(user: user, topicDataSource: topicDataSource, postDataSource: postDataSource)
  }

  var blocked: Bool {
    !user.id.isEmpty && blockWords.blocked(user: user.name)
  }

  var shouldShowList: Bool {
    !user.id.isEmpty && !user.isAnonymous && !blocked
  }

  @ViewBuilder
  var list: some View {
    switch tab {
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
              // My profile may show on the 2nd stack, requiring cross-stack.
              CrossStackNavigationLinkHack(destination: TopicDetailsView.build(topicBinding: topic), id: topic.w.id) {
                TopicRowView(topic: topic.w)
              }.onAppear { topicDataSource.loadMoreIfNeeded(currentItem: topic.w) }
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
            ForEach($postDataSource.items, id: \.post.id) { tpBinding in
              let tp = tpBinding.w
              // My profile may show on the 2nd stack, requiring cross-stack.
              // FIXME: we cannot know the page where the post is located at the original topic.
              CrossStackNavigationLinkHack(destination: TopicDetailsView.build(topicBinding: tpBinding.topic, onlyPost: (id: tp.post.id, atPage: nil)), id: tp.post.id) {
                TopicPostRowView(topic: tp.topic, post: tp.post)
              }.onAppear { postDataSource.loadMoreIfNeeded(currentItem: tp) }
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
        }.pickerStyle(SegmentedPickerStyle())
          .frame(minWidth: 160)
      }
    }

    if !isMyself {
      ToolbarItem(placement: .mayNavigationBarTrailing) {
        Menu {
          if !user.isAnonymous {
            Section {
              Button(action: { newShortMessage() }) {
                Label("New Short Message", systemImage: "message")
              }
            }
          }
          Section {
            Button(role: blocked ? nil : .destructive, action: { blockWords.toggle(user: user.name) }) {
              if blocked {
                Label("Unblock This User", systemImage: "hand.raised")
              } else {
                Label("Block This User", systemImage: "hand.raised")
              }
            }
          }
        } label: {
          Label("More", systemImage: "ellipsis")
        }
      }
    }
  }

  var title: String {
    user.isAnonymous ? "Anonymous User".localized : user.name.display
  }

  var body: some View {
    List {
      Section(header: Text("User Profile")) {
        UserView(user: user, style: .huge, loadRemote: true)

        let sig = user.signature
        if !sig.spans.isEmpty, !blocked {
          UserSignatureView(content: sig, font: .callout, color: .primary)
        }
      }

      if shouldShowList {
        list
      } else if blocked {
        EmptyRowView(title: "Blocked")
      }
    }
    .toolbar { toolbar }
    .withTopicDetailsAction() // for signature only
    .mayGroupedListStyle()
    .navigationTitleInline(string: title)
  }

  func newShortMessage() {
    guard checkPlus(.shortMessage) else { return }

    postModel.show(action: .with {
      $0.operation = .newSingleTo
      $0.singleTo = user.name.normal
    })
  }
}
