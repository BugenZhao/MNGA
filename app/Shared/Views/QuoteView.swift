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
  @ViewBuilder let build: () -> Content

  var body: some View {
    HStack {
      build()
      if fullWidth { Spacer() }
    } .padding(.small)
      .background(
      RoundedRectangle(cornerRadius: 12)
      #if os(iOS)
        .fill(Color.systemGroupedBackground)
      #endif
    )
  }
}
