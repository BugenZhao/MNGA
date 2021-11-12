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

#if os(iOS)
  import SwiftUIRefresh
#endif

class PagingDataSource<Res: SwiftProtobuf.Message, Item>: ObservableObject {
  private let buildRequest: (_ page: Int) -> AsyncRequest.OneOf_Value
  private let onResponse: (_ response: Res) -> ([Item], Int?)
  private let id: KeyPath<Item, String>
  private let finishOnError: Bool
  private let neverRemove: Bool

  @Published var items = [Item]()
  @Published var itemToIndexAndPage = [String: (index: Int, page: Int)]()
  @Published var isLoading = false
  @Published var isRefreshing = false
  @Published var latestResponse: Res?
  @Published var lastRefreshTime: Date?
  @Published var loadFromPage: Int?

  private var loadedPage = 0
  private var totalPages = 1
  private var dataFlowId = UUID()

  private var cancellables = Set<AnyCancellable>()

  var hasMore: Bool { loadedPage < totalPages }
  var nextPage: Int? { hasMore ? loadedPage + 1 : nil }
  var isInitialLoading: Bool { isLoading && loadedPage == 0 }
  var firstLoadedPage: Int? { itemToIndexAndPage.values.map { $0.page }.min() }
  var notLoaded: Bool { items.isEmpty && lastRefreshTime == nil }

  init(
    buildRequest: @escaping (_ page: Int) -> AsyncRequest.OneOf_Value,
    onResponse: @escaping (_ response: Res) -> ([Item], Int?),
    id: KeyPath<Item, String>,
    finishOnError: Bool = false,
    loadFromPage: Int? = nil,
    neverRemove: Bool = false
  ) {
    self.buildRequest = buildRequest
    self.onResponse = onResponse
    self.id = id
    self.finishOnError = finishOnError
    self.loadFromPage = loadFromPage
    self.neverRemove = neverRemove

    $loadFromPage
      .drop { $0 == nil }
      .sink { self.refresh(fromPage: $0 ?? 1) }
      .store(in: &cancellables)
  }

  func sortedItems<Key: Comparable>(by key: KeyPath<Item, Key>) -> [Item] {
    self.items.sorted { $0[keyPath: key] < $1[keyPath: key] }
  }

  func itemsAtPage(_ page: Int) -> [Item] {
    items.filter { item in
      let id = item[keyPath: id]
      return itemToIndexAndPage[id]!.page == page
    }
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
    if neverRemove == false {
      self.items.removeAll()
      self.itemToIndexAndPage.removeAll()
    }
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

  private func mayFinishOnError() {
    if finishOnError {
      self.totalPages = self.loadedPage
    }
  }

  private func preRefresh(fromPage: Int) -> AsyncRequest.OneOf_Value? {
    if self.isRefreshing || self.isLoading { return nil }
    self.dataFlowId = UUID()

    self.isLoading = true
    self.isRefreshing = true
    self.loadedPage = fromPage - 1
    self.totalPages = fromPage

    let page = fromPage
    let request = buildRequest(page)
    return request
  }

  private func onRefreshSuccess(response: Res, animated: Bool, fromPage: Int) {
    self.latestResponse = response
    let (newItems, newTotalPages) = self.onResponse(response)
    logger.debug("page \(self.loadedPage + 1), newItems \(newItems.count)")

    withAnimation(when: animated) {
      self.replaceItems(newItems, page: fromPage)
      self.isRefreshing = false
      self.isLoading = false
    }

    self.totalPages = newTotalPages ?? self.totalPages
    self.loadedPage += 1
    self.lastRefreshTime = Date()
  }

  private func onRefreshError(e: LogicError, animated: Bool) {
    withAnimation(when: animated) {
      self.isRefreshing = false
      self.isLoading = false
    }
    self.mayFinishOnError()
  }

  func refresh(animated: Bool = false, silentOnError: Bool = false, fromPage: Int = 1) {
    guard let request = preRefresh(fromPage: fromPage) else { return }

    logicCallAsync(request, errorToastModel: silentOnError ? nil : .hud) { (response: Res) in
      self.onRefreshSuccess(response: response, animated: animated, fromPage: fromPage)
    } onError: { e in
      self.onRefreshError(e: e, animated: animated)
    }
  }

  #if os(iOS)
    @available(iOS 15.0, *)
    func refreshAsync(animated: Bool = false, fromPage: Int = 1) async {
      let request = DispatchQueue.main.sync { preRefresh(fromPage: fromPage) }
      guard let request = request else { return }

      let response: Result<Res, LogicError> = await logicCallAsync(request)

      DispatchQueue.main.sync {
        switch response {
        case .success(let response):
          self.onRefreshSuccess(response: response, animated: animated, fromPage: fromPage)
        case .failure(let e):
          self.onRefreshError(e: e, animated: animated)
        }
      }
    }
  #endif

  func initialLoad() {
    if self.loadedPage == 0 {
      refresh(animated: true)
    }
  }

  func reloadLastPages(evenIfNotLoaded: Bool) {
    for page in [totalPages, totalPages + 1] {
      reload(page: page, evenIfNotLoaded: evenIfNotLoaded)
    }
  }

  func reload(page: Int, evenIfNotLoaded: Bool, animated: Bool = true, after: (() -> Void)? = nil) {
    guard page <= loadedPage || evenIfNotLoaded else { return }
    let request = buildRequest(page)
    let currentId = dataFlowId

    logicCallAsync(request) { (response: Res) in
      guard currentId == self.dataFlowId else { return }

      self.latestResponse = response
      let (newItems, newTotalPages) = self.onResponse(response)

      withAnimation(when: animated) {
        self.upsertItems(newItems, page: page)
        self.isLoading = false
      }
      self.totalPages = newTotalPages ?? self.totalPages
      if let after = after { after() }
    } onError: { e in
      withAnimation {
        self.isLoading = false
      }
      self.mayFinishOnError()
    }
  }

  private func loadMore(background: Bool = false, alwaysAnimation: Bool = false) {
    if isLoading || loadedPage >= totalPages { return }
    isLoading = true

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
      self.mayFinishOnError()
    }
  }
}


extension View {
  func refreshable<Res, Item>(dataSource: PagingDataSource<Res, Item>, iOS15Only: Bool = false, refreshWhenEnterForeground: Bool = false) -> some View {
    #if canImport(SwiftUIRefresh)
      Group {
        if #available(iOS 15.0, *) {
          self.refreshable {
            await Task.sleep(UInt64(0.25 * Double(NSEC_PER_SEC)))
            await dataSource.refreshAsync(animated: true)
            await Task.sleep(UInt64(0.25 * Double(NSEC_PER_SEC)))
          }
        } else if !iOS15Only {
          self.pullToRefresh(isShowing: .constant(dataSource.isRefreshing)) { dataSource.refresh(animated: true) }
        } else {
          self
        }
      }
// refreshWhenEnterForeground is currently buggy

//      .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
//        guard refreshWhenEnterForeground else { return }
//        guard let last = dataSource.lastRefreshTime else { return }
//
//        let elasped = Date().timeIntervalSince(last)
//        if elasped > 60 * 60 { // 1 hour elapsed
//          dataSource.refresh()
//        }
//      }
    #else
      self
    #endif
  }
}
