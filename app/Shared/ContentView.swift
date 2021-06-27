//
//  ContentView.swift
//  Shared
//
//  Created by Bugen Zhao on 6/27/21.
//

import SwiftUI

struct ReplyView: View {
  let reply: Reply

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Image(systemName: "person.circle.fill")
          .resizable()
          .frame(width: 28, height: 28)
        VStack(alignment: .leading) {
          Text(reply.authorID)
            .font(.subheadline)
          Text("#\(reply.floor)")
            .font(.footnote)
            .foregroundColor(.secondary)
        }
      }
      Text(reply.content)
        .font(.callout)
    }
  }
}

struct TopicDetailsView: View {
  let topicID: String

  @State private var replies = [Reply]()
  @State private var topic: Topic?

  private var first: Reply? { replies.first }

  var body: some View {
    let inner = VStack {
      if replies.isEmpty {
        ProgressView()
          .onAppear { refresh() }
      } else {
        let list = List {
          if let first = self.first {
            Section(header: Text("Topic")) {
              ReplyView(reply: first)
            }
          }
          Section(header: Text("Replies")) {
            ForEach(replies.dropFirst(), id: \.floor) { ReplyView(reply: $0) }
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
      .navigationTitle("Topic Details")

    #if os(iOS)
      inner
        .navigationBarTitleDisplayMode(.inline)
    #elseif os(macOS)
      inner
    #endif
  }

  func refresh() {
    let request = TopicDetailsRequest.with {
      $0.topicID = topicID
      $0.page = 1
    }
    logicCallAsync(.topicDetails(request)) { (response: TopicDetailsResponse) in
      topic = response.topic
      replies = response.replies
    }
  }
}

struct TopicView: View {
  let topic: Topic

  private let dateFormatter = RelativeDateTimeFormatter()

  var body: some View {
    let date = Date(timeIntervalSince1970: TimeInterval(topic.lastPostDate))
    let dateString = dateFormatter.localizedString(for: date, relativeTo: Date())

    return VStack(alignment: .leading, spacing: 8) {
      Text(topic.subject)
        .font(.callout)
        .lineLimit(2)

      HStack {
        HStack(alignment: .center) {
          Image(systemName: "person")
          Text(topic.authorName)
        }
          .font(.footnote)
          .foregroundColor(.secondary)
        Spacer()
        Text(dateString)
          .font(.caption)
          .foregroundColor(.secondary)
      }
    }
  }
}

struct ContentView: View {
  @State private var topics = [Topic]()

  var body: some View {
    NavigationView {
      List {
        ForEach(topics, id: \.id) { topic in
          NavigationLink(destination: TopicDetailsView(topicID: topic.id)) {
            TopicView(topic: topic)
          }
        }
      }
        .onAppear { if topics.isEmpty { refresh() } }
        .navigationTitle("Topics")
        .toolbar {
        ToolbarItem {
          Button(action: refresh) {
            Image(systemName: "arrow.clockwise.circle")
          }
        }
      }
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
