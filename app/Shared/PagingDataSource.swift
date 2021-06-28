//
//  PagingDataSource.swift
//  NGA
//
//  Created by Bugen Zhao on 6/27/21.
//

import Foundation
import Combine
import SwiftProtobuf

class PagingDataSource<Res: SwiftProtobuf.Message, Item>: ObservableObject {
  private let buildRequest: (_ page: Int) -> AsyncRequest.OneOf_Value
  private let onResponse: (_ response: Res) -> ([Item], Int?)
  private let id: KeyPath<Item, String>

  @Published var items = [Item]()
  @Published var isLoading = false
  @Published var latestResponse: Res?

  private var loadedPage = 0
  private var totalPages = 1
  private var dataFlowId = UUID()

  init(
    buildRequest: @escaping (_ page: Int) -> AsyncRequest.OneOf_Value,
    onResponse: @escaping (_ response: Res) -> ([Item], Int?),
    id: KeyPath<Item, String>
  ) {
    self.buildRequest = buildRequest
    self.onResponse = onResponse
    self.id = id

    loadMore()
  }

  func loadMoreIfNeeded(currentItem: Item) {
    if let index = items.firstIndex(where: { $0[keyPath: id] == currentItem[keyPath: id] }) {
      let threshold = items.index(items.endIndex, offsetBy: -5)
      if index >= threshold { loadMore() }
    }
  }

  func refresh() {
    self.dataFlowId = UUID()

    self.isLoading = true
    self.loadedPage = 0
    self.totalPages = 1

    let request = buildRequest(1)
    logicCallAsync(request) { (response: Res) in
      self.latestResponse = response
      let (newItems, newTotalPages) = self.onResponse(response)
      print("page \(self.loadedPage + 1), newItems \(newItems.count)")

      self.items = newItems
      self.totalPages = newTotalPages ?? self.totalPages
      self.loadedPage += 1
      self.isLoading = false
    }
  }

  private func loadMore() {
    if isLoading || loadedPage >= totalPages { return }
    isLoading = true;

    let request = buildRequest(loadedPage + 1)
    let currentId = dataFlowId

    logicCallAsync(request) { (response: Res) in
      guard currentId == self.dataFlowId else { return }

      self.latestResponse = response
      let (newItems, newTotalPages) = self.onResponse(response)
      print("page \(self.loadedPage + 1), newItems \(newItems.count)")

      self.items += newItems
      self.totalPages = newTotalPages ?? self.totalPages
      self.loadedPage += 1
      self.isLoading = false
    }
  }
}
