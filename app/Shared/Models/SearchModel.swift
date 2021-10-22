//
//  SearchModel.swift
//  NGA
//
//  Created by Bugen Zhao on 7/12/21.
//

import Foundation
import SwiftProtobuf
import Combine

class SearchModel<Res: SwiftProtobuf.Message, Item>: ObservableObject {
  typealias DataSource = PagingDataSource<Res, Item>

  @Published var text = ""
  @Published var commitedText: String? = nil
  @Published var isEditing = false
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
