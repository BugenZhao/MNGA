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
    let dataSource = DataSource.init(
      buildRequest: { page in
        return .shortMessageList(.with { $0.page = UInt32(page) })
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
    Button(action: { self.newShortMessage() }) {
      Label("New Short Message", systemImage: "square.and.pencil")
    }
  }

  var body: some View {
    List {
      ForEach(dataSource.items, id: \.id) { message in
        NavigationLink(destination: { ShortMessageDetailsView.build(mid: message.id) }) {
          ShortMessageRowView(message: message)
        } .onAppear { dataSource.loadMoreIfNeeded(currentItem: message) }
      }
    } .navigationTitle("Short Messages")
      .onAppear { dataSource.initialLoad() }
      .mayGroupedListStyle()
      .refreshable(dataSource: dataSource)
      .toolbarWithFix { ToolbarItem(placement: .primaryAction) { newShortMessageButton } }
      .onChange(of: postModel.sent) { _ in dataSource.reload(page: 1, evenIfNotLoaded: false) }
  }

  func newShortMessage() {
    self.postModel.show(action: .with {
      $0.operation = .new
    })
  }
}
