//
//  Divided.swift
//  MNGA
//
//  Created by Bugen Zhao on 2026/01/26.
//

import SwiftUI

struct Divided<Content: View>: View {
  var content: Content

  init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  var body: some View {
    _VariadicView.Tree(DividedLayout()) {
      content
    }
  }

  struct DividedLayout: _VariadicView_MultiViewRoot {
    @ViewBuilder
    func body(children: _VariadicView.Children) -> some View {
      let last = children.last?.id

      ForEach(children) { child in
        child

        if child.id != last {
          Divider()
        }
      }
    }
  }
}
