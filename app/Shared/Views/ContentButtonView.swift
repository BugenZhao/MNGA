//
//  ContentButtonView.swift
//  ContentButtonView
//
//  Created by Bugen Zhao on 8/22/21.
//

import Foundation
import SwiftUI
import SwiftUIX

struct ContentButtonView<T: View>: View {
  let icon: String
  let title: T
  let inQuote: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack {
        Image(systemName: icon)
        title
      }.foregroundColor(.accentColor)
        .font(.footnote)
        .lineLimit(3)
        .padding(.small)
        .background(
          RoundedRectangle(cornerRadius: 12)
            .fill(inQuote ? Color.secondarySystemGroupedBackground : Color.systemGroupedBackground)
        )
    }.buttonStyle(PlainButtonStyle())
  }
}
