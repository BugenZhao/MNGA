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
      .sink { _ in self.commitedText = nil }
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

  init(commited: Bool = true) {
    super.init()

    if commited {
      $commitedText
        .map { t -> DataSource? in
          if let t { self.buildDataSource(text: t) }
          else { nil }
        }
        .assign(to: &$dataSource)
    } else {
      $text
        .map(buildDataSource(text:))
        .assign(to: &$dataSource)
    }
  }
}

class AutoSearchModel<DS>: BasicSearchModel {
  typealias DataSource = DS

  @Published var dataSource: DataSource? = nil

  func buildDataSource(text _: String) -> DataSource {
    preconditionFailure()
  }

  override init() {
    super.init()

    $text
      .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
      .removeDuplicates()
      .map(buildDataSource(text:))
      .assign(to: &$dataSource)
  }
}

struct SearchableModifier: ViewModifier {
  @ObservedObject var model: BasicSearchModel
  let prompt: String
  let alwaysShow: Bool
  let iOS15Only: Bool

  func body(content: Content) -> some View {
    if #available(iOS 15.0, *) {
      content
        .searchable(text: $model.text, placement: alwaysShow ? .navigationBarDrawer(displayMode: .always) : .automatic, prompt: prompt)
        .onSubmit(of: .search) { model.commit() }
    } else if iOS15Only {
      content
    } else {
      content
      #if os(iOS)
      .navigationSearchBar {
        SearchBar(
          prompt,
          text: $model.text,
          onCommit: { model.commit() }
        )
        .onCancel { model.cancel() }
      }
      .navigationSearchBarHiddenWhenScrolling(!alwaysShow)
      #endif
    }
  }
}

extension View {
  func searchable(model: BasicSearchModel, prompt: String, alwaysShow: Bool = false, iOS15Only: Bool = false) -> some View {
    modifier(SearchableModifier(model: model, prompt: prompt, alwaysShow: alwaysShow, iOS15Only: iOS15Only))
  }
}
