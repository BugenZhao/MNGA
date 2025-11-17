//
//  SafeForEach.swift
//  MNGA
//
//  Created by Bugen Zhao on 2025/11/17.
//

import SwiftUI

struct SafeBindingView<Item, ID: Hashable, Content: View>: View {
  let items: Binding<[Item]>
  let idPath: KeyPath<Item, ID>
  let id: ID
  let build: (Binding<Item>) -> Content

  @State var cachedItem: Item

  init?(
    items: Binding<[Item]>,
    item: Item,
    id: KeyPath<Item, ID>,
    build: @escaping (Binding<Item>) -> Content
  ) {
    self.items = items
    idPath = id
    self.id = item[keyPath: id]
    self.build = build
    _cachedItem = State(wrappedValue: item)
  }

  var binding: Binding<Item> {
    Binding(
      get: {
        if let v = items.wrappedValue.first(where: { $0[keyPath: idPath] == id }) {
          return v // always sync from list when available
        }
        logger.debug("binding is invalidated, get cached \(Item.self) instead")
        return cachedItem
      },
      set: { newValue in
        if let index = items.wrappedValue.firstIndex(where: { $0[keyPath: idPath] == id }) {
          items.wrappedValue[index] = newValue
          cachedItem = newValue
        } else {
          // list no longer contains it, update only the local copy
          logger.debug("binding is invalidated, set cached \(Item.self) instead")
          cachedItem = newValue
        }
      }
    )
  }

  var body: some View {
    build(binding)
  }
}

struct SafeForEach<Item, ID: Hashable, Content: View>: View {
  let items: Binding<[Item]>
  let idPath: KeyPath<Item, ID>
  let build: (Binding<Item>) -> Content
  let predicate: ((Item) -> Bool)?

  init(
    _ items: Binding<[Item]>,
    id: KeyPath<Item, ID>,
    where predicate: ((Item) -> Bool)? = nil,
    @ViewBuilder build: @escaping (Binding<Item>) -> Content,
  ) {
    self.items = items
    idPath = id
    self.build = build
    self.predicate = predicate
  }

  var visibleItems: [Item] {
    if let predicate {
      items.wrappedValue.filter(predicate)
    } else {
      items.wrappedValue
    }
  }

  var body: some View {
    ForEach(visibleItems, id: idPath) { item in
      SafeBindingView(items: items, item: item, id: idPath, build: build)
    }
  }
}

extension SafeForEach: DynamicViewContent {
  typealias Data = [Item]

  var data: [Item] {
    items.wrappedValue
  }
}
