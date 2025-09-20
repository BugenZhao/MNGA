//
//  PagingDataSource.swift
//  NGA
//
//  Created by Bugen Zhao on 6/27/21.
//

import Combine
import Foundation
import SwiftProtobuf
import SwiftUI

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
  @Published var latestError: LogicError?
  @Published var lastRefreshTime: Date? // only successful refresh
  @Published var loadFromPage: Int?

  private var loadedPage = 0
  private var totalPages = 1
  private var dataFlowId = UUID()

  private var cancellables = Set<AnyCancellable>()

  var hasMore: Bool { loadedPage < totalPages }
  var nextPage: Int? { hasMore ? loadedPage + 1 : nil }
  var isInitialLoading: Bool { isLoading && loadedPage == 0 }
  var firstLoadedPage: Int? { itemToIndexAndPage.values.map(\.page).min() }
  var notLoaded: Bool { items.isEmpty && lastRefreshTime == nil && latestError == nil }

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

  func sortedItems(by key: KeyPath<Item, some Comparable>) -> [Item] {
    items.sorted { $0[keyPath: key] < $1[keyPath: key] }
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

  private func upsertItems(_ items: some Sequence<Item>, page: Int) {
    for item in items {
      let id = item[keyPath: id]

      if let index = itemToIndexAndPage[id]?.index {
        self.items[index] = item
      } else { // is new
        self.items.append(item)
        itemToIndexAndPage[id] = (index: self.items.endIndex - 1, page: page)
      }
    }
  }

  private func replaceItems(_ items: some Sequence<Item>, page: Int) {
    if neverRemove == false {
      self.items.removeAll()
      itemToIndexAndPage.removeAll()
    }
    upsertItems(items, page: page)
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

  private func onError(_ e: LogicError) {
    if finishOnError {
      totalPages = loadedPage
    }
    latestError = e
  }

  private func preRefresh(fromPage: Int) -> AsyncRequest.OneOf_Value? {
    if isRefreshing || isLoading { return nil }
    dataFlowId = UUID()

    isLoading = true
    isRefreshing = true
    loadedPage = fromPage - 1
    totalPages = fromPage

    let page = fromPage
    let request = buildRequest(page)
    return request
  }

  private func onRefreshSuccess(response: Res, animated: Bool, fromPage: Int) {
    latestResponse = response
    latestError = nil
    let (newItems, newTotalPages) = onResponse(response)
    logger.debug("page \(loadedPage + 1), newItems \(newItems.count)")

    withAnimation(when: animated) {
      self.replaceItems(newItems, page: fromPage)
      self.isRefreshing = false
      self.isLoading = false
    }

    totalPages = newTotalPages ?? totalPages
    loadedPage += 1
    lastRefreshTime = Date()
  }

  private func onRefreshError(_ e: LogicError, animated: Bool) {
    withAnimation(when: animated) {
      self.isRefreshing = false
      self.isLoading = false
    }
    onError(e)
  }

  func refresh(animated: Bool = false, silentOnError: Bool = false, fromPage: Int = 1) {
    guard let request = preRefresh(fromPage: fromPage) else { return }

    logicCallAsync(request, errorToastModel: silentOnError ? nil : .banner) { (response: Res) in
      self.onRefreshSuccess(response: response, animated: animated, fromPage: fromPage)
    } onError: { e in
      self.onRefreshError(e, animated: animated)
    }
  }

  func refreshAsync(animated: Bool = false, fromPage: Int = 1) async {
    let request = DispatchQueue.main.sync { preRefresh(fromPage: fromPage) }
    guard let request else { return }

    let response: Result<Res, LogicError> = await logicCallAsync(request)

    DispatchQueue.main.sync {
      switch response {
      case let .success(response):
        self.onRefreshSuccess(response: response, animated: animated, fromPage: fromPage)
      case let .failure(e):
        self.onRefreshError(e, animated: animated)
      }
    }
  }

  func initialLoad() {
    if loadedPage == 0, latestError == nil {
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
      self.latestError = nil
      let (newItems, newTotalPages) = self.onResponse(response)

      withAnimation(when: animated) {
        self.upsertItems(newItems, page: page)
        self.isLoading = false
      }
      self.totalPages = newTotalPages ?? self.totalPages
      if let after { after() }
    } onError: { e in
      withAnimation {
        self.isLoading = false
      }
      self.onError(e)
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
      self.latestError = nil
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
      self.onError(e)
    }
  }
}

struct PagingDataSourceRefreshable<Res: SwiftProtobuf.Message, Item>: ViewModifier {
  let dataSource: PagingDataSource<Res, Item>
  let refreshWhenEnterForeground: Bool

  @Environment(\.scenePhase) var scenePhase

  func doRefresh() async {
    try? await Task.sleep(nanoseconds: UInt64(0.25 * Double(NSEC_PER_SEC)))
    await dataSource.refreshAsync(animated: true)
    try? await Task.sleep(nanoseconds: UInt64(0.25 * Double(NSEC_PER_SEC)))
  }

  func body(content: Content) -> some View {
    ScrollViewReader { proxy in
      content
        .refreshable { await doRefresh() }
        .if(refreshWhenEnterForeground) {
          $0.onChange(of: scenePhase) {
            logger.debug("scenePhase changed from \($0) to \($1)")
            // Swipe to home: active -> inactive -> background
            // Back to app: background -> inactive -> active
            // When in multitask mode, app can be inactive if it's not focused.
            // So we detect the switch from inactive to active, but not from background.
            guard $0 == .inactive, $1 == .active else { return }
            guard let last = dataSource.lastRefreshTime else { return }

            let elapsed = Date().timeIntervalSince(last)
            if elapsed > 60 * 60 { // 1 hour
              Task {
                logger.debug("\(elapsed) seconds elapsed, refreshing...")
                withAnimation { proxy.scrollTo("top-placeholder") }
                await doRefresh()
                ToastModel.showAuto(.autoRefreshed)
              }
            }
          }
        }
    }
  }
}

extension View {
  func refreshable<Res: SwiftProtobuf.Message, Item>(dataSource: PagingDataSource<Res, Item>, refreshWhenEnterForeground: Bool = false) -> some View {
    modifier(PagingDataSourceRefreshable(dataSource: dataSource, refreshWhenEnterForeground: refreshWhenEnterForeground))
  }
}
