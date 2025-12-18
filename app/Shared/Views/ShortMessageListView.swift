//
//  ShortMessageListView.swift
//  MNGA
//
//  Created by Bugen Zhao on 2021/10/16.
//

import Foundation
import SwiftUI

struct ShortMessageListView: View {
  typealias DataSource = PagingDataSource<ShortMessageListResponse, ShortMessage>

  @StateObject var dataSource: DataSource

  @EnvironmentObject var postModel: ShortMessagePostModel

  static func build() -> Self {
    let dataSource = DataSource(
      buildRequest: { page in
        .shortMessageList(.with { $0.page = UInt32(page) })
      },
      onResponse: { response in
        let items = response.messages
        let pages = response.pages
        return (items, Int(pages))
      },
      id: \.id
    )

    return Self(dataSource: dataSource)
  }

  @ViewBuilder
  var newShortMessageButton: some View {
    Button(action: { newShortMessage() }) {
      Label("New Short Message", systemImage: "square.and.pencil")
    }
  }

  @ToolbarContentBuilder
  var toolbar: some ToolbarContent {
    MaybeToolbarSpacer(placement: .bottomBar)
    ToolbarItem(placement: .bottomBar) { newShortMessageButton }
  }

  var body: some View {
    Group {
      if dataSource.notLoaded {
        ProgressView()
          .onAppear { dataSource.initialLoad() }
      } else if dataSource.items.isEmpty {
        ContentUnavailableView("No Short Messages", systemImage: "envelope")
      } else {
        List {
          ForEach(dataSource.items, id: \.id) { message in
            CrossStackNavigationLinkHack(id: message.id, destination: {
              ShortMessageDetailsView.build(mid: message.id)
            }) {
              ShortMessageRowView(message: message)
            }.onAppear { dataSource.loadMoreIfNeeded(currentItem: message) }
          }
        }
      }
    }
    .navigationTitle("Short Messages")
    .mayGroupedListStyle()
    .refreshable(dataSource: dataSource)
    .toolbar { toolbar }
    .onChange(of: postModel.sent) { dataSource.reload(page: 1, evenIfNotLoaded: false) }
  }

  func newShortMessage() {
    guard checkPlus(.shortMessage) else { return }

    postModel.show(action: .with {
      $0.operation = .new
    })
  }
}
