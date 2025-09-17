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

  var deviceSpecificPlacement: SearchFieldPlacement {
    if UserInterfaceIdiom.current == .pad {
      // By `.toolbar` the search field from every column will all be placed in
      // the top-right corner, which seems weird.
      .navigationBarDrawer(displayMode: .always)
    } else {
      .automatic
    }
  }

  func body(content: Content) -> some View {
    content
      .searchable(text: $model.text, placement: deviceSpecificPlacement, prompt: prompt)
      .onSubmit(of: .search) { model.commit() }
  }
}

extension View {
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
