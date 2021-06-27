//
//  ContentView.swift
//  Shared
//
//  Created by Bugen Zhao on 6/27/21.
//

import SwiftUI

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
          Text(topic.author)
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
  @State var topics = [Topic]()

  var body: some View {
    NavigationView {
      List {
        ForEach(topics, id: \.id) { TopicView(topic: $0) }
      }
        .onAppear { refresh() }
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
    ContentView()
  }
}
