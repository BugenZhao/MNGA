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

  @StateObject var dataSource: PagingDataSource<TopicDetailsResponse, Reply>
  @State var showFullTitle = false

  init(topic: Topic) {
    self.topic = topic

    let dataSource = PagingDataSource<TopicDetailsResponse, Reply>(
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

  private var first: Reply? { dataSource.items.first }

  var title: String {
    let id = NSLocalizedString("Topic", comment: "") + " #\(topic.id)"
    let subject = topic.subject

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
            Text(topic.subject)
              .font(.headline)
              .onAppear { showFullTitle = false }
              .onDisappear { showFullTitle = true }
          }
          if let first = self.first {
            ReplyView(reply: first)
          }

        }

        if dataSource.items.count > 1 {
          Section(header: Text("Replies")) {
            ForEach(dataSource.items.dropFirst(), id: \.floor) { reply in
              ReplyView(reply: reply)
                .onAppear { dataSource.loadMoreIfNeeded(currentItem: reply)
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
          $0.id = "27447557"
          $0.subject = "Topic Title"
        })
      }
    }
  }
}
