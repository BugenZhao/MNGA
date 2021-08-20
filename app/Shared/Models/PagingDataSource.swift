//
//  PagingDataSource.swift
//  NGA
//
//  Created by Bugen Zhao on 6/27/21.
//

import Foundation
import Combine
import SwiftProtobuf
import SwiftUI

class PagingDataSource<Res: SwiftProtobuf.Message, Item>: ObservableObject {
  private let buildRequest: (_ page: Int) -> AsyncRequest.OneOf_Value
  private let onResponse: (_ response: Res) -> ([Item], Int?)
  private let id: KeyPath<Item, String>

  @Published var items = [Item]()
  @Published var itemToIndexAndPage = [String: (index: Int, page: Int)]()
  @Published var isLoading = false
  @Published var isRefreshing = false
  @Published var latestResponse: Res?

  private var loadedPage = 0
  private var totalPages = 1
  private var dataFlowId = UUID()

  var hasMore: Bool { loadedPage < totalPages }
  var nextPage: Int? { hasMore ? loadedPage + 1 : nil }
  var isInitialLoading: Bool { isLoading && loadedPage == 0 }

  init(
    buildRequest: @escaping (_ page: Int) -> AsyncRequest.OneOf_Value,
    onResponse: @escaping (_ response: Res) -> ([Item], Int?),
    id: KeyPath<Item, String>
  ) {
    self.buildRequest = buildRequest
    self.onResponse = onResponse
    self.id = id
  }

  func sortedItems<Key: Comparable>(by key: KeyPath<Item, Key>) -> [Item] {
    self.items.sorted { $0[keyPath: key] < $1[keyPath: key] }
  }

  var pagedItems: [(page: Int, items: [Item])] {
    var pagedItems = [Int: [Item]]()
    for item in items {
      let id = item[keyPath: id]
      let page = itemToIndexAndPage[id]!.page
      pagedItems[page, default: []].append(item)
    }
    return pagedItems.sorted { $0.key < $1.key }.map { (page: $0.key, items: $0.value) }
  }

  private func upsertItems<S>(_ items: S, page: Int) where S: Sequence, S.Element == Item {
    items.forEach {
      let id = $0[keyPath: self.id]

      if let index = self.itemToIndexAndPage[id]?.index {
        self.items[index] = $0
      } else { // is new
        self.items.append($0)
        self.itemToIndexAndPage[id] = (index: self.items.endIndex - 1, page: page)
      }
    }
  }

  private func replaceItems<S>(_ items: S, page: Int) where S: Sequence, S.Element == Item {
    self.items.removeAll()
    self.itemToIndexAndPage.removeAll()
    self.upsertItems(items, page: page)
  }

  func loadMore(after: Double = 0.0) {
    DispatchQueue.main.asyncAfter(deadline: .now() + after) {
      self.loadMore(background: false, alwaysAnimation: true)
    }
  }

  func loadMoreIfNeeded(currentItem: Item) {
    if let index = itemToIndexAndPage[currentItem[keyPath: id]]?.index {
      let threshold = items.index(items.endIndex, offsetBy: -2)
      if index >= threshold { loadMore(background: true) }
    }
  }

  func refresh(animated: Bool = false) {
    if self.isRefreshing || self.isLoading { return }
    self.dataFlowId = UUID()

    self.isLoading = true
    self.isRefreshing = true
    self.loadedPage = 0
    self.totalPages = 1

    let page = 1
    let request = buildRequest(page)
    logicCallAsync(request) { (response: Res) in
      self.latestResponse = response
      let (newItems, newTotalPages) = self.onResponse(response)
      logger.debug("page \(self.loadedPage + 1), newItems \(newItems.count)")

      withAnimation(when: animated) {
        self.replaceItems(newItems, page: page)
        self.isRefreshing = false
        self.isLoading = false
      }

      self.totalPages = newTotalPages ?? self.totalPages
      self.loadedPage += 1
    } onError: { e in
      withAnimation(when: animated) {
        self.isRefreshing = false
        self.isLoading = false
      }
    }
  }

  func initialLoad() {
    if self.loadedPage == 0 {
      loadMore()
    }
  }

  func reloadLastPages(evenIfNotLoaded: Bool) {
    for page in [totalPages, totalPages + 1] {
      reload(page: page, evenIfNotLoaded: evenIfNotLoaded)
    }
  }

  func reload(page: Int, evenIfNotLoaded: Bool) {
    guard page <= loadedPage || evenIfNotLoaded else { return }
    let request = buildRequest(page)
    let currentId = dataFlowId

    logicCallAsync(request) { (response: Res) in
      guard currentId == self.dataFlowId else { return }

      self.latestResponse = response
      let (newItems, newTotalPages) = self.onResponse(response)

      withAnimation {
        self.upsertItems(newItems, page: page)
        self.isLoading = false
      }
      self.totalPages = newTotalPages ?? self.totalPages
    } onError: { e in
      withAnimation {
        self.isLoading = false
      }
    }
  }

  private func loadMore(background: Bool = false, alwaysAnimation: Bool = false) {
    if isLoading || loadedPage >= totalPages { return }
    isLoading = true;

    let page = loadedPage + 1
    let request = buildRequest(page)
    let currentId = dataFlowId

    let queue = DispatchQueue.global(qos: background ? .background : .userInitiated)

    logicCallAsync(request, requestDispatchQueue: queue) { (response: Res) in
      guard currentId == self.dataFlowId else { return }

      self.latestResponse = response
      let (newItems, newTotalPages) = self.onResponse(response)
      logger.debug("page \(self.loadedPage + 1), newItems \(newItems.count)")

      withAnimation(when: self.items.isEmpty || alwaysAnimation) {
        self.upsertItems(newItems, page: page)
        self.isLoading = false
      }
      self.totalPages = newTotalPages ?? self.totalPages
      self.loadedPage += 1
    } onError: { e in
      withAnimation(when: self.items.isEmpty) {
        self.isLoading = false
      }
    }
  }
}
