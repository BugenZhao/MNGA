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

  @Published var rootFrame: CGRect = .infinite

  // Whether the content column still shows its placeholder.
  var isContentColumnEmpty = false

  /// Collapsing leaves the visibility at detail only, and the system writes it again for a moment
  /// after expanding, so adjust it once that has settled: show the sidebar if there is nothing
  /// else to see, or bring the content column back otherwise.
  func settleAfterExpanding() {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      if self.isContentColumnEmpty {
        self.showOverlaidSidebar()
      } else if self.value == .detailOnly {
        self.value = .doubleColumn
      }
    }
  }

  private func showOverlaidSidebar() {
    guard rootFrame.width < Self.tiledSidebarMinWidth else { return }
    guard value == .all else {
      value = .all
      return
    }
    // The system may have hidden the sidebar without writing it back, so make it a real change.
    value = .doubleColumn
    // The next run loop turn can be too soon, and the two writes then reach the system as one.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { self.value = .all }
  }

  /// An overlaid sidebar covers the content column it navigates, so hide it after navigating.
  func hideOverlaidSidebar() {
    if value == .all, rootFrame.width < Self.tiledSidebarMinWidth {
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

  // The trailing edge of the content this button belongs to, in the global coordinates.
  let contentMaxX: CGFloat

  var body: some View {
    if let columnVisibility,
       columnVisibility.value != .detailOnly,
       // It keeps only the detail column, which is the one at the trailing edge. Anywhere else,
       // such as column 2 or a sheet, it would hide the content or change what's behind it.
       contentMaxX >= columnVisibility.rootFrame.maxX - 1
    {
      Button(action: { columnVisibility.value = .detailOnly }) {
        Image(systemName: "arrow.up.left.and.arrow.down.right")
      }
    }
  }
}

struct FullScreenButtonToolbarItem: ToolbarContent {
  @Environment(\.usesColumnLayout) var usesColumnLayout

  let contentMaxX: CGFloat

  var body: some ToolbarContent {
    if usesColumnLayout {
      // TODO: `topBarLeading` places it after the back button if there is one,
      // while the built-in sidebar button is before the back button.
      ToolbarItem(placement: .topBarLeading) { FullScreenButtonView(contentMaxX: contentMaxX) }
    }
  }
}
