//
//  DiceView.swift
//  MNGA
//
//  Created by Bugen Zhao on 2/11/25.
//

import Foundation
import SwiftUI

struct DiceView: View {
  @StateObject var prefs = PreferencesStorage.shared
  @State var showingExpanded = false

  let result: DiceRoller.Result

  init(resolved result: DiceRoller.Result) {
    self.result = result
  }

  init(unresolvedExpression: String) {
    result = .init(originalExpression: unresolvedExpression, expandedExpression: "???", totalDescription: "???")
  }

  var font: Font {
    if prefs.postRowLargerFont {
      .callout
    } else {
      .subheadline
    }
  }

  var body: some View {
    QuoteView(fullWidth: false, background: .accentColor.opacity(0.15)) {
      HStack(alignment: .center) {
        Image(systemName: "dice.fill")
          .foregroundColor(.accentColor)
          .bold()
          .symbolRenderingMode(.hierarchical)

        Group {
          let eq = Text(" → ").monospaced(false)
          let original = Text(result.originalExpression)
          let expanded = Text(result.expandedExpression).foregroundColor(.secondary)
          let total = Text(result.totalDescription).bold()

          if showingExpanded {
            Text("\(original)\(eq)\(expanded)\(eq)\(total)")
          } else {
            Text("\(original)\(eq)\(total)")
          }
        }
      }
      .font(font.monospaced())
    }
    .contentShape(.rect)
    .onTapGesture { withAnimation { showingExpanded.toggle() } }
  }
}
