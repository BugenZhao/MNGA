import SwiftUI

struct FollowUserListView: View {
  typealias DataSource = PagingDataSource<FollowUserListResponse, User>

  @StateObject private var dataSource: DataSource

  init() {
    _dataSource = StateObject(wrappedValue: DataSource(
      buildRequest: { page in
        .followUserList(.with { $0.page = UInt32(page) })
      },
      onResponse: { ($0.users, Int($0.pages)) },
      id: \.id,
    ))
  }

  var body: some View {
    List {
      if dataSource.notLoaded {
        LoadingRowView().onAppear { dataSource.initialLoad() }
      } else if dataSource.items.isEmpty {
        EmptyRowView(title: "No Followed Users")
      } else {
        ForEach(dataSource.items, id: \.id) { user in
          NavigationLink(destination: UserProfileView.build(user: user)) {
            UserView(user: user, style: .normal)
          }
          .onAppear { dataSource.loadMoreIfNeeded(currentItem: user) }
        }
      }
    }
    .refreshable { await dataSource.refreshAsync(animated: true) }
    .mayGroupedListStyle()
    .navigationTitle("Following")
  }
}

struct FollowActivityRowView: View {
  let activity: FollowActivity

  var destination: some View {
    let postID: PostId? = activity.hasPost ? activity.post.id : nil
    return TopicDetailsView.build(topicBinding: .constant(activity.topic), onlyPost: (postID, nil))
  }

  var body: some View {
    CrossStackNavigationLinkHack(destination: destination, id: activity.id) {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          UserView(user: activity.user, style: .compact)
          Spacer()
          Text(activity.type == .reply ? "Posted a Reply" : "Published a Topic")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        if activity.hasPost {
          TopicPostRowView(topic: activity.topic, post: activity.post)
        } else {
          TopicRowView(topic: activity.topic, useTopicPostDate: true, dimmedSubject: false)
        }
      }
      .padding(.vertical, 2)
    }
  }
}

struct FollowActivityListView: View {
  typealias DataSource = PagingDataSource<FollowActivityListResponse, FollowActivity>

  @StateObject private var dataSource: DataSource

  init() {
    _dataSource = StateObject(wrappedValue: DataSource(
      buildRequest: { page in
        .followActivityList(.with { $0.page = UInt32(page) })
      },
      onResponse: { ($0.activities, Int($0.pages)) },
      id: \.id,
    ))
  }

  var body: some View {
    List {
      if dataSource.notLoaded {
        LoadingRowView().onAppear { dataSource.initialLoad() }
      } else if dataSource.items.isEmpty {
        EmptyRowView(title: "No Following Activity")
      } else {
        ForEach(dataSource.items, id: \.id) { activity in
          FollowActivityRowView(activity: activity)
            .onAppear { dataSource.loadMoreIfNeeded(currentItem: activity) }
        }
      }
    }
    .refreshable { await dataSource.refreshAsync(animated: true) }
    .mayGroupedListStyle()
    .navigationTitle("Following Activity")
  }
}
