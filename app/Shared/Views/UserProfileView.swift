//
//  UserProfileView.swift
//  UserProfileView
//
//  Created by Bugen Zhao on 2021/9/10.
//

import Combine
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

  @State var user: User

  @StateObject var topicDataSource: TopicDataSource
  @StateObject var postDataSource: PostDataSource

  @EnvironmentObject var postModel: ShortMessagePostModel
  @EnvironmentObject var signaturePostModel: UserSignaturePostModel
  @EnvironmentObject var currentUser: CurrentUserModel

  @StateObject var blockWords = BlockWordsStorage.shared
  @StateObject var users = UsersModel.shared

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
      id: \.id,
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
      finishOnError: true,
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
            SafeForEach($topicDataSource.items, id: \.id) { topic in
              // My profile may show on the 2nd stack, requiring cross-stack.
              TopicRowLinkView(topic: topic)
                .onAppear { topicDataSource.loadMoreIfNeeded(currentItem: topic.w) }
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
            SafeForEach($postDataSource.items, id: \.post.id) { tpBinding in
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

    ToolbarItem(placement: .mayNavigationBarTrailing) {
      Menu {
        if isMyself {
          Section {
            Button(action: { editSignature() }) {
              Label("Edit Signature", systemImage: "pencil.line")
            }
          }
        }

        if !isMyself {
          Section {
            if !user.isAnonymous {
              Button(action: { newShortMessage() }) {
                Label("New Short Message", systemImage: "message")
              }
            }
            Button(role: blocked ? nil : .destructive, action: { blockWords.toggle(user: user.name) }) {
              if blocked {
                Label("Unblock This User", systemImage: "hand.raised")
              } else {
                Label("Block This User", systemImage: "hand.raised")
              }
            }
          }
        }

        if !user.isAnonymous {
          Section {
            ShareLinksView(navigationID: .userID(user.id), shareTitle: user.name.display)
          }
        }
      } label: {
        Label("More", systemImage: "ellipsis".maybeCircledSymbol)
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
    .onChange(of: signaturePostModel.sent) {
      guard isMyself, $1?.task.action.userID == user.id else { return }
      Task { await reloadUser() }
    }
    .refreshable { await refresh() }
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

  func editSignature() {
    guard isMyself else { return }
    let initial = user.signature.rawReplacingBr
    signaturePostModel.show(action: .init(userID: user.id, initialSignature: initial))
  }

  func reloadUser() async {
    if let refreshed = await users.remoteUser(id: user.id, ignoreCache: true) {
      withAnimation { user = refreshed }
    }
  }

  func refresh() async {
    await withTaskGroup { group in
      group.addTask { await reloadUser() }
      if shouldShowList {
        group.addTask { await topicDataSource.refreshAsync(animated: true) }
        group.addTask { await postDataSource.refreshAsync(animated: true) }
      }
    }
  }
}

struct RemoteUserProfileView: View {
  let req: RemoteUserRequest
  let dummyName: String

  @State var user: User?

  init(id: String) {
    req = .with { $0.userID = id }
    dummyName = id
  }

  init(name: String) {
    req = .with { $0.userName = name }
    dummyName = name
  }

  var body: some View {
    if let user {
      UserProfileView.build(user: user)
    } else {
      ProgressView()
        .navigationTitleInline(string: dummyName)
        .task {
          if let remoteUser = await UsersModel.shared.remoteUser(req) {
            withAnimation { user = remoteUser }
          }
        }
    }
  }
}
