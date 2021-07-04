//
//  TopicDetails.swift
//  NGA
//
//  Created by Bugen Zhao on 6/28/21.
//

import Foundation
import SwiftUI
import SwiftUIX

struct TopicDetailsView: View {
  let topic: Topic

  @StateObject var dataSource: PagingDataSource<TopicDetailsResponse, Post>
  @State var showFullTitle = false

  init(topic: Topic) {
    self.topic = topic

    let dataSource = PagingDataSource<TopicDetailsResponse, Post>(
      buildRequest: { page in
        return .topicDetails(TopicDetailsRequest.with {
          $0.topicID = topic.id
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

  private var first: Post? { dataSource.items.first }

  var title: String {
    let id = NSLocalizedString("Topic", comment: "") + " #\(topic.id)"
    let subject = topic.subjectFull

    switch UserInterfaceIdiom.current {
    case .pad, .mac:
      return [id, subject].joined(separator: " ")
    default:
      return showFullTitle ? subject : id
    }
  }

  var body: some View {
    let inner = VStack(alignment: .leading) {
      let list = List {
        Section(header: HStack {
          Text("Topic")
          if dataSource.isLoading {
            Spacer()
            ProgressView()
          }
        }) {
          if UserInterfaceIdiom.current == .phone {
            TopicSubjectView(topic: topic)
              .onAppear { showFullTitle = false }
              .onDisappear { showFullTitle = true }
          }
          if let first = self.first {
            PostView(post: first)
          }

        }

        if dataSource.items.count > 1 {
          Section(header: Text("Replies")) {
            ForEach(dataSource.items.dropFirst(), id: \.floor) { post in
              PostView(post: post)
                .onAppear { dataSource.loadMoreIfNeeded(currentItem: post)
              }
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
      .navigationTitle(title)
      .onFirstAppear { dataSource.initialLoad() }

    #if os(iOS)
      inner
        .navigationBarTitleDisplayMode(.inline)
    #elseif os(macOS)
      inner
    #endif
  }
}


struct TopicDetailsView_Preview: PreviewProvider {
  static var previews: some View {
    AuthedPreview {
      NavigationView {
        TopicDetailsView(topic: Topic.with {
          $0.id = "27458657"
          $0.subjectContent = "Topic Title"
        })
      }
    }
//    .preferredColorScheme(.dark)
  }
}
