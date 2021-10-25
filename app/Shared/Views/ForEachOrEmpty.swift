//
//  ForEachOrEmpty.swift
//  MNGA
//
//  Created by Bugen Zhao on 2021/10/25.
//

import Foundation
import SwiftUI

struct EmptyRowView: View {
  var body: some View {
    HStack {
      Spacer()
      Text("Empty")
      Spacer()
    }
  }
}

struct ForEachOrEmpty<Data, ID, Content>: View where Data: RandomAccessCollection, ID: Hashable, Content: View {
  let data: Data
  let id: KeyPath<Data.Element, ID>
  let content: (Data.Element) -> Content

  init(_ data: Data, id: KeyPath<Data.Element, ID>, @ViewBuilder content: @escaping (Data.Element) -> Content) {
    self.data = data
    self.id = id
    self.content = content
  }

  var body: some View {
    if data.isEmpty {
      EmptyRowView()
    } else {
      ForEach(data, id: id, content: content)
    }
  }
}
