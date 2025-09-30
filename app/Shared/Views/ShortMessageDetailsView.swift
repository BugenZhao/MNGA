//
//  ShortMessageDetailsView.swift
//  MNGA
//
//  Created by Bugen Zhao on 2021/10/19.
//

import Foundation
import SwiftUI

struct ShortMessageDetailsView: View {
  typealias DataSource = PagingDataSource<ShortMessageDetailsResponse, ShortMessagePost>

  let mid: String

  @StateObject var dataSource: DataSource

  @EnvironmentObject var postModel: ShortMessagePostModel

  static func build(mid: String) -> Self {
    let dataSource = DataSource(
      buildRequest: { page in
        .shortMessageDetails(.with {
          $0.id = mid
          $0.page = UInt32(page)
        })
      },
      onResponse: { response in
        let items = response.posts
        let pages = response.pages
        return (items, Int(pages))
      },
      id: \.id
    )

    return Self(mid: mid, dataSource: dataSource)
  }

  var debugID: String {
    "#\(mid)"
  }

  @ViewBuilder
  var replyButton: some View {
    Button(action: { doReply() }) {
      Label("Reply", systemImage: "arrowshape.turn.up.left")
    }
  }

  @ToolbarContentBuilder
  var toolbar: some ToolbarContent {
    ToolbarSpacer(placement: .bottomBar)
    ToolbarItem(placement: .bottomBar) { replyButton }
  }

  var body: some View {
    Group {
      if dataSource.notLoaded {
        ProgressView()
          .onAppear { dataSource.initialLoad() }
      } else {
        List {
          Section(header: Text("Participants")) {
            ScrollView(.horizontal) {
              LazyHStack {
                ForEach(dataSource.latestResponse?.users ?? [], id: \.id) { user in
                  UserView(user: user, style: .vertical)
                }
              }
            }
          }

          Section {
            ForEach(dataSource.items, id: \.id) { post in
              ShortMessagePostRowView(post: post)
                .onAppear { dataSource.loadMoreIfNeeded(currentItem: post) }
            }
          }
        }
      }
    }.navigationTitleInline(key: "Short Message Details")
      .navigationSubtitle(debugID)
      .mayGroupedListStyle()
      .refreshable(dataSource: dataSource)
      .withTopicDetailsAction()
      .toolbar { toolbar }
      .onChange(of: postModel.sent) { dataSource.reloadLastPages(evenIfNotLoaded: false) }
  }

  func doReply() {
    guard checkPlus(.shortMessage) else { return }

    postModel.show(action: .with {
      $0.operation = .reply
      $0.mid = mid
    })
  }
}
