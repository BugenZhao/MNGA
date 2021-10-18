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

  @StateObject var dataSource: DataSource

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

    return Self(dataSource: dataSource)
  }

  var body: some View {
    List {
      ForEach(dataSource.items, id: \.id) { post in
        ShortMessagePostRowView(post: post)
          .onAppear { dataSource.loadMoreIfNeeded(currentItem: post) }
      }
    } .navigationTitleInline(key: "Short Message Details")
      .onAppear { dataSource.initialLoad() }
      .mayGroupedListStyle()
      .refreshable(dataSource: dataSource)
  }
}
