//
//  CrossStackNavigationLink.swift
//  MNGA
//
//  Created by Bugen Zhao on 2025-09-17.
//

import SwiftUI

/// A NavigationLink wrapper that automatically adds an id to the destination view
/// to ensure cross-column navigation triggers refresh on different selection.
///
/// This solves the cross-column navigation issue in SwiftUI where the destination
/// view doesn't refresh properly when navigating between different items.
///
/// Only needed when it's dynamic, e.g., within a `ForEach`.
struct CrossStackNavigationLinkHack<Destination: View, Label: View>: View {
  private let destination: Destination
  private let id: AnyHashable
  private let label: Label

  init(destination: Destination, id: some Hashable, @ViewBuilder label: () -> Label) {
    self.destination = destination
    self.id = AnyHashable(id)
    self.label = label()
  }

  var body: some View {
    NavigationLink(destination: destination.id(id)) {
      label
    }
  }
}

// MARK: - Convenience initializers for closure-based destinations

extension CrossStackNavigationLinkHack where Label: View {
  init(id: some Hashable, @ViewBuilder destination: () -> Destination, @ViewBuilder label: () -> Label) {
    self.destination = destination()
    self.id = AnyHashable(id)
    self.label = label()
  }
}
