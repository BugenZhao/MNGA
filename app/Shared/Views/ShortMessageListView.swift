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

  var body: some View {
    List {
      ForEach(dataSource.items, id: \.id) { message in
        NavigationLink(destination: Text("233")) {
          ShortMessageRowView(message: message)
        } .onAppear { dataSource.loadMoreIfNeeded(currentItem: message) }
      }
    } .navigationTitle("Short Messages")
      .onAppear { dataSource.initialLoad() }
      .mayGroupedListStyle()
      .refreshable(dataSource: dataSource)
  }
}


