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
}

fileprivate class MenuDelegate: NSObject, UIContextMenuInteractionDelegate {
  let actions: [CellAction]

  init(actions: [CellAction]) {
    self.actions = actions
  }

  func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
    let configuration = UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
      let children = self.actions.map { action in
        UIAction(
          title: NSLocalizedString(action.title, comment: ""),
          image: UIImage(systemName: action.systemImage),
          identifier: nil,
          attributes: []) { _ in
          action.callback()
        }
      }

      return UIMenu(children: children)
    }
    return configuration
  }
}

// BUGEN'S HACK:
// This modifier is intended to improve the scrolling performance on list cells with context menu
struct CellContextMenuModifier: ViewModifier {
  @State private var delegate: MenuDelegate  // stored since `interaction` holds a weak ref
  @State var interaction: UIContextMenuInteraction // stored as `State` to avoid add multiple times

  init(actions: [CellAction]) {
    let delegate = MenuDelegate(actions: actions)
    let interaction = UIContextMenuInteraction(delegate: delegate)
    self.delegate = delegate
    self.interaction = interaction
  }

  func body(content: Content) -> some View {
    content.introspectTableViewCell { cell in
      if cell.interactions.contains(where: { ($0 as? UIContextMenuInteraction)?.delegate != nil }) { return }
      cell.addInteraction(interaction)
    }
  }
}

extension View {
  func cellContextMenu(actions: [CellAction]) -> some View {
    self.modifier(CellContextMenuModifier(actions: actions))
  }
}
