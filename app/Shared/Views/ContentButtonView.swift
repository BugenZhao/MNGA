//
//  ContentButtonView.swift
//  ContentButtonView
//
//  Created by Bugen Zhao on 8/22/21.
//

import Foundation
import SwiftUI
import SwiftUIX

struct ContentButtonView: View {
  let icon: String
  let title: Text
  let inQuote: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      (Text(Image(systemName: icon)) + Text(" ") + title)
        .lineLimit(1)
        .font(.footnote)
        .foregroundColor(.accentColor)
        .padding(.small)
        .background(
        RoundedRectangle(cornerRadius: 12)
        #if os(iOS)
          .fill(inQuote ? Color.secondarySystemGroupedBackground : Color.systemGroupedBackground)
        #endif
      )
    } .buttonStyle(.plain)
  }
}
