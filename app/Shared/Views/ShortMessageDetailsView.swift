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
    let dataSource = DataSource.init(
      buildRequest: { page in
        return .shortMessageDetails(.with {
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

  @ViewBuilder
  var replyButton: some View {
    Button(action: { self.doReply() }) {
      Label("Reply", systemImage: "arrowshape.turn.up.left")
    }
  }

  var body: some View {
    Group {
      if dataSource.notLoaded {
        ProgressView()
          .onAppear { dataSource.initialLoad() }
      } else {
        List {
          ForEach(dataSource.items, id: \.id) { post in
            ShortMessagePostRowView(post: post)
              .onAppear { dataSource.loadMoreIfNeeded(currentItem: post) }
          }
        }
      }
    } .navigationTitleInline(key: "Short Message Details")
      .mayGroupedListStyle()
      .refreshable(dataSource: dataSource)
      .withTopicDetailsAction()
      .toolbarWithFix { ToolbarItem(placement: .primaryAction) { replyButton } }
      .onChange(of: postModel.sent) { _ in dataSource.reloadLastPages(evenIfNotLoaded: false) }
  }

  func doReply() {
    self.postModel.show(action: .with {
      $0.operation = .reply
      $0.mid = mid
    })
  }
}
