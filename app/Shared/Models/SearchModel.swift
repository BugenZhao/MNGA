//
//  SearchModel.swift
//  NGA
//
//  Created by Bugen Zhao on 7/12/21.
//

import Combine
import Foundation
import SwiftProtobuf
import SwiftUI
import SwiftUIX

class BasicSearchModel: ObservableObject {
  @Published var text = ""
  @Published var commitedText: String? = nil

  private var cancellables = Set<AnyCancellable>()

  init() {
    $text
      .filter(\.isEmpty)
      .sink { [weak self] _ in self?.commitedText = nil }
      .store(in: &cancellables)
  }

  func commit() {
    commitedText = text
  }

  func cancel() {
    commitedText = nil
  }
}

class SearchModel<DS>: BasicSearchModel {
  typealias DataSource = DS

  @Published var dataSource: DataSource? = nil

  func buildDataSource(text _: String) -> DataSource {
    preconditionFailure()
  }

  override init() {
    super.init()

    $commitedText
      .map { t -> DataSource? in
        if let t { self.buildDataSource(text: t) }
        else { nil }
      }
      .assign(to: &$dataSource)
  }
}

struct SearchableModifier: ViewModifier {
  @ObservedObject var model: BasicSearchModel
  let prompt: String

  @Environment(\.usesColumnLayout) var usesColumnLayout

  var layoutSpecificPlacement: SearchFieldPlacement {
    if usesColumnLayout {
      // By `.toolbar` the search field from every column will all be placed in
      // the top-right corner, which seems weird.
      .navigationBarDrawer(displayMode: .automatic)
    } else {
      .automatic
    }
  }

  func body(content: Content) -> some View {
    content
      .searchable(text: $model.text, placement: layoutSpecificPlacement, prompt: prompt)
      .onSubmit(of: .search) { model.commit() }
  }
}

/// Loads a search result data source once its view is on screen.
///
/// A new data source is built for every committed keyword, and the results view may stay on
/// screen while that happens: global search commits on every keystroke and its results live in
/// another column, and a search inside a forum swaps its results in place. Keying the load on the
/// data source identity makes the new one load too, instead of showing its spinner forever.
/// Replacements wait for a short pause, so the intermediate keywords of a word being typed don't
/// each send a request.
private struct SearchResultsLoader<Res: SwiftProtobuf.Message, Item>: ViewModifier {
  let dataSource: PagingDataSource<Res, Item>

  @State private var hasLoaded = false

  func body(content: Content) -> some View {
    // The new data source is built while the old one is still referenced, so the two never
    // share an object identifier.
    content.task(id: ObjectIdentifier(dataSource)) {
      if hasLoaded {
        do { try await Task.sleep(for: .seconds(0.4)) } catch { return }
      }
      hasLoaded = true
      dataSource.initialLoad()
    }
  }
}

/// Placeholder shown when a search has nothing to list, telling a failed request apart from an
/// empty result.
struct SearchResultsUnavailableView: View {
  let error: LogicError?

  var body: some View {
    if let error {
      ContentUnavailableView {
        Label("Search Failed", systemImage: "exclamationmark.magnifyingglass")
      } description: {
        Text(error.error.errorLocalized)
      }
    } else {
      ContentUnavailableView("No Results", systemImage: "magnifyingglass")
    }
  }
}

extension View {
  func loadsSearchResults(_ dataSource: PagingDataSource<some SwiftProtobuf.Message, some Any>) -> some View {
    modifier(SearchResultsLoader(dataSource: dataSource))
  }

  func searchable(model: BasicSearchModel, prompt: String, if: Bool = true) -> some View {
    Group {
      if `if` {
        modifier(SearchableModifier(model: model, prompt: prompt))
      } else {
        self
      }
    }
  }
}
