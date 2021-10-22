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

class SearchModel<Res: SwiftProtobuf.Message, Item>: ObservableObject {
  typealias DataSource = PagingDataSource<Res, Item>

  @Published var text = ""
  @Published private var commitedText: String? = nil
  @Published var dataSource: DataSource? = nil

  private var cancellables = Set<AnyCancellable>()

  func buildDataSource(text: String) -> DataSource {
    preconditionFailure()
  }

  init() {
    $text
      .filter { $0.isEmpty }
      .sink { _ in self.commitedText = nil }
      .store(in: &cancellables)

    $commitedText
      .map { (t) -> DataSource? in
      if let t = t { return self.buildDataSource(text: t) }
      else { return nil }
    }
      .assign(to: &$dataSource)
  }

  func commit() {
    commitedText = text
  }

  func cancel() {
    commitedText = nil
  }
}

struct SearchableModifier<Res: SwiftProtobuf.Message, Item>: ViewModifier {
  @ObservedObject var model: SearchModel<Res, Item>
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
  func searchable<Res, Item>(model: SearchModel<Res, Item>, prompt: String, alwaysShow: Bool = false, iOS15Only: Bool = false) -> some View {
    self
      .modifier(SearchableModifier(model: model, prompt: prompt, alwaysShow: alwaysShow, iOS15Only: iOS15Only))
  }
}
