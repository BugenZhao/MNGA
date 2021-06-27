//
//  ContentView.swift
//  Shared
//
//  Created by Bugen Zhao on 6/27/21.
//

import SwiftUI
import RemoteImage

struct ReplyView: View {
  let reply: Reply
  let user: User?

  init(reply: Reply) {
    self.reply = reply
    self.user = try! (logicCall(.localUser(.with { $0.userID = reply.authorID })) as LocalUserResponse).user
  }

  var body: some View {
    let user = self.user

    VStack(alignment: .leading, spacing: 8) {
      HStack {
        avatar
          .frame(width: 28, height: 28)
          .clipShape(Circle())
        VStack(alignment: .leading) {
          Text(user?.name ?? reply.authorID)
            .font(.subheadline)
          Text("#\(reply.floor)")
            .font(.footnote)
            .foregroundColor(.secondary)
        }
        Spacer()
        if reply.score > 0 {
          HStack {
            Text("\(reply.score)")
              .fontWeight(.medium)
            Image(systemName: "chevron.up")
          }
            .font(.callout)
        }
      }
      Text(reply.content)
        .font(.callout)
    }
  }

  var avatar: AnyView {
    let placeholder = Image(systemName: "person.circle.fill").resizable()

    if let url = URL(string: user?.avatarURL ?? "") {
      return AnyView(RemoteImage(
        type: .url(url),
        errorView: { _ in placeholder },
        imageView: { $0.resizable() },
        loadingView: { placeholder }
        ))
    } else {
      return AnyView(placeholder)
    }
  }
}

struct TopicDetailsView: View {
  let topicID: String

  @StateObject var dataSource: PagingDataSource<TopicDetailsResponse, Reply>

  init(topicID: String) {
    self.topicID = topicID

    let dataSource = PagingDataSource<TopicDetailsResponse, Reply>(
      buildRequest: { page in
        return .topicDetails(TopicDetailsRequest.with {
          $0.topicID = topicID
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
    self._dataSource = StateObject(wrappedValue: dataSource)
  }

  private var first: Reply? { dataSource.items.first }

  private var topic: Topic? { dataSource.latestResponse?.topic }

  var body: some View {
    #if os(iOS)
      let title = "Topic Details #\(topicID)"
    #elseif os(macOS)
      let title = "#\(topicID) " + (topic?.subject ?? "")
    #endif

    let inner = VStack(alignment: .leading) {
      if dataSource.items.isEmpty {
        ProgressView()
      } else {
        #if os(iOS)
          if let subject = topic?.subject {
            Text(subject)
              .font(.headline)
              .padding()
          }
        #endif

        let list = List {
          if let first = self.first {
            Section(header: Text("Topic")) {
              ReplyView(reply: first)
            }
          }
          Section(header: Text("Replies")) {
            ForEach(dataSource.items.dropFirst(), id: \.floor) { reply in
              ReplyView(reply: reply)
                .onAppear { dataSource.loadMoreIfNeeded(currentItem: reply)
              }
            }
          }
        }

        #if os(iOS)
          list
            .listStyle(GroupedListStyle())
        #elseif os(macOS)
          list
        #endif
      }
    }
      .navigationTitle(title)

    #if os(iOS)
      inner
        .navigationBarTitleDisplayMode(.inline)
    #elseif os(macOS)
      inner
    #endif
  }
}

struct TopicView: View {
  let topic: Topic

  private let dateFormatter = RelativeDateTimeFormatter()

  var body: some View {
    let date = Date(timeIntervalSince1970: TimeInterval(topic.lastPostDate))
    let dateString = dateFormatter.localizedString(for: date, relativeTo: Date())

    return VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(topic.subject)
          .font(.callout)
          .lineLimit(2)
        Spacer()
        Text("\(topic.repliesNum)")
          .fontWeight(.medium)
      }

      HStack {
        HStack(alignment: .center) {
          Image(systemName: "person")
          Text(topic.authorName)
        }
        Spacer()
        Text(dateString)
      }
        .foregroundColor(.secondary)
        .font(.footnote)
    }
  }
}

struct TopicListView: View {
  @StateObject var dataSource: PagingDataSource<TopicListResponse, Topic>

  init() {
    let dataSource = PagingDataSource<TopicListResponse, Topic>(
      buildRequest: { page in
        return .topicList(TopicListRequest.with {
          $0.forumID = "-7"
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
            let destination = NavigationLazyView(TopicDetailsView(topicID: topic.id))

            NavigationLink(destination: destination) {
              TopicView(topic: topic)
                .onAppear { dataSource.loadMoreIfNeeded(currentItem: topic) }
            }
          }
        }

        #if os(iOS)
          list
            .listStyle(GroupedListStyle())
        #elseif os(macOS)
          list
        #endif
      }
    }
      .navigationTitle("Topics")
      .toolbar {
      ToolbarItem {
        Button(action: { dataSource.refresh() }) {
          Image(systemName: "arrow.clockwise.circle")
        }
      }
    }
  }
}

struct ContentView: View {
  @State private var topics = [Topic]()

  var body: some View {
    NavigationView {
      TopicListView()
    }
  }

  func refresh() {
    let request = TopicListRequest.with {
      $0.forumID = "-7"
      $0.page = 1
    }
    logicCallAsync(.topicList(request)) { (response: TopicListResponse) in
      topics = response.topics
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    Group {
      ContentView()
      TopicDetailsView(topicID: "27351344")
    }
  }
}
