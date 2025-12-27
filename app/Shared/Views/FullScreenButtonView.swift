//
//  FullScreenButtonView.swift
//  MNGA
//
//  Created by Bugen Zhao on 2025/12/27.
//

import SwiftUI
import SwiftUIX

class ColumnVisibility: ObservableObject {
  @Published var value: NavigationSplitViewVisibility = .all
}

/// Toggle full screen mode (detail only column visibility) on iPad.
struct FullScreenButtonView: View {
  @EnvironmentObject.Optional var columnVisibility: ColumnVisibility?

  var body: some View {
    if let columnVisibility,
       columnVisibility.value != .detailOnly
    {
      Button(action: { columnVisibility.value = .detailOnly }) {
        Image(systemName: "arrow.up.left.and.arrow.down.right")
      }
    }
  }
}

struct FullScreenButtonToolbarItem: ToolbarContent {
  var body: some ToolbarContent {
    if UserInterfaceIdiom.current == .pad {
      // TODO: `topBarLeading` places it after the back button if there is one,
      // while the built-in sidebar button is before the back button.
      ToolbarItem(placement: .topBarLeading) { FullScreenButtonView() }
    }
  }
}
