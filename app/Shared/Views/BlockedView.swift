//
//  BlockedView.swift
//  BlockedView
//
//  Created by Bugen Zhao on 7/19/21.
//

import Foundation
import SwiftUI

struct BlockedView<Content>: View where Content: View {
  let content: String
  let revealOnTap: Bool
  let build: () -> Content

  @StateObject var blockWords = BlockWordsStorage.shared
  @State var hidden = true

  var shouldHide: Bool {
    hidden && blockWords.blocked(content)
  }

  var body: some View {
    let view = build()
      .redacted(if: shouldHide)

    if revealOnTap {
      view
        .onTapGesture { withAnimation { hidden = false } }
    } else {
      view
    }
  }
}
