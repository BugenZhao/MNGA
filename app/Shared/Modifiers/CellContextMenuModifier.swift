//
//  CellContextMenuModifier.swift
//  MNGA
//
//  Created by Bugen Zhao on 2021/10/3.
//

import Foundation
import SwiftUI

struct CellAction {
  let title: String
  let systemImage: String
  let callback: () -> Void

  static var separator = nil as CellAction?
}

fileprivate class MenuDelegate: NSObject, UIContextMenuInteractionDelegate {
  let actions: [CellAction?]

  init(actions: [CellAction?]) {
    self.actions = actions
  }

  func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
    UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
      let actions = self.actions.map { action -> UIMenuElement? in
        guard let action = action else { return nil }
        return UIAction(
          title: NSLocalizedString(action.title, comment: ""),
          image: UIImage(systemName: action.systemImage),
          handler: { _ in action.callback() }
        )
      }

      let children = actions.split(separator: nil).enumerated().flatMap { (i, actions) -> [UIMenuElement] in
        let actions = actions.compactMap { $0 }
        if i == 0 {
          return actions
        } else {
          return [UIMenu(options: .displayInline, children: actions)]
        }
      }

      return UIMenu(children: children)
    }
  }
}

// BUGEN'S HACK:
// This modifier is intended to improve the scrolling performance on list cells with context menu
//
// BUGGY, DO NOT USE
struct CellContextMenuModifier: ViewModifier {
  private let delegate: MenuDelegate
  private let interaction: UIContextMenuInteraction

  init(actions: [CellAction?]) {
    // CAVEATS: do not store `delegate` as @State or only add the interaction once,
    //          since the partial applied `self` (SwiftUI View) in callbacks may be stale after rebuilt
    self.delegate = MenuDelegate(actions: actions)
    self.interaction = UIContextMenuInteraction(delegate: self.delegate)
  }

  func body(content: Content) -> some View {
    content.introspectTableViewCell { cell in
      cell.interactions.removeAll()
      cell.addInteraction(interaction)
    }
  }
}

extension View {
  func cellContextMenu(actions: [CellAction?]) -> some View {
    self.modifier(CellContextMenuModifier(actions: actions))
  }
}
