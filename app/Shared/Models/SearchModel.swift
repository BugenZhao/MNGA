//
//  SearchModel.swift
//  NGA
//
//  Created by Bugen Zhao on 7/12/21.
//

import Foundation
import SwiftProtobuf
import Combine
import SwiftUI
import SwiftUIX

class BasicSearchModel: ObservableObject {
  @Published var text = ""
  @Published var commitedText: String? = nil

  private var cancellables = Set<AnyCancellable>()

  init() {
    $text
      .filter { $0.isEmpty }
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

class SearchModel<Res: SwiftProtobuf.Message, Item>: BasicSearchModel {
  typealias DataSource = PagingDataSource<Res, Item>

  @Published var dataSource: DataSource? = nil

  func buildDataSource(text: String) -> DataSource {
    preconditionFailure()
  }

  override init() {
    super.init()

    $commitedText
      .map { (t) -> DataSource? in
      if let t = t { return self.buildDataSource(text: t) }
      else { return nil }
    }
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
    self
      .modifier(SearchableModifier(model: model, prompt: prompt, alwaysShow: alwaysShow, iOS15Only: iOS15Only))
  }
}
