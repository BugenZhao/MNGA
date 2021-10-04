//
//  QuoteView.swift
//  QuoteView
//
//  Created by Bugen Zhao on 7/18/21.
//

import Foundation
import SwiftUI

struct QuoteView<Content>: View where Content: View {
  let fullWidth: Bool
  let background: Color
  let build: () -> Content

  init(fullWidth: Bool, background: Color = .systemGroupedBackground, @ViewBuilder build: @escaping () -> Content) {
    self.fullWidth = fullWidth
    self.background = background
    self.build = build
  }

  var body: some View {
    build()
      .frame(maxWidth: fullWidth ? .infinity : nil, alignment: .topLeading)
      .padding(.small)
      .background(
      RoundedRectangle(cornerRadius: 12)
      #if os(iOS)
        .fill(background)
      #endif
    )
  }
}
