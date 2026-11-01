//
//  FullScreenButtonView.swift
//  MNGA
//
//  Created by Bugen Zhao on 2025/12/27.
//

import SwiftUI
import SwiftUIX

class ColumnVisibility: ObservableObject {
  // Below this width, the system overlays the sidebar on the content column rather than
  // tiling three columns, whatever the column widths or the split view style are.
  private static let tiledSidebarMinWidth: CGFloat = 1100

  @Published var value: NavigationSplitViewVisibility = .all

  var rootWidth: CGFloat = .infinity

  /// An overlaid sidebar covers the content column it navigates, so hide it after navigating.
  func hideOverlaidSidebar() {
    if value == .all, rootWidth < Self.tiledSidebarMinWidth {
      value = .doubleColumn
    }
  }
}

private struct HidesOverlaidSidebarModifier: ViewModifier {
  @EnvironmentObject.Optional var columnVisibility: ColumnVisibility?

  func body(content: Content) -> some View {
    content.onAppear { columnVisibility?.hideOverlaidSidebar() }
  }
}

extension View {
  /// Apply this to the destination of a navigation from the sidebar to the content column.
  func hidesOverlaidSidebar() -> some View {
    modifier(HidesOverlaidSidebarModifier())
  }
}

/// Toggle full screen mode (detail only column visibility) when showing columns.
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
  @Environment(\.usesColumnLayout) var usesColumnLayout

  var body: some ToolbarContent {
    if usesColumnLayout {
      // TODO: `topBarLeading` places it after the back button if there is one,
      // while the built-in sidebar button is before the back button.
      ToolbarItem(placement: .topBarLeading) { FullScreenButtonView() }
    }
  }
}
