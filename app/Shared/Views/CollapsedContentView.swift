//
//  CollapsedContentView.swift
//  NGA
//
//  Created by Bugen Zhao on 7/13/21.
//

import Foundation
import SwiftUI

struct CollapsedContentView<Content: View>: View {
  let title: String
  @ViewBuilder let content: () -> Content

  @State private var collapsed: Bool = true

  var body: some View {
    VStack(alignment: .leading) {
      Button(action: { collapsed.toggle() }) {
        HStack {
          Image(systemName: collapsed ? "chevron.down" : "chevron.up")
            .contentTransition(
              .symbolEffect(.replace.magic(fallback: .downUp)),
            )
          Text(title)
            .animation(.none, value: collapsed) // disable animation to avoid glitch
        }.padding(.bottom, 1)
          .foregroundColor(.accentColor)
          .font(.subheadline.bold())
      }.buttonStyle(.plain)

      Group {
        if !collapsed {
          content()
        }
      }
    }.fixedSize(horizontal: false, vertical: true)
  }
}

struct CollapsedContentView_Previews: PreviewProvider {
  static var previews: some View {
    List {
      ForEach(1 ... 10, id: \.self) { i in
        VStack(alignment: .leading) {
          Text(String(repeating: "Content \(i) ", count: 20))
          CollapsedContentView(title: "Title") {
            Text(String(repeating: "Collapsed \(i) ", count: 20))
          }
        }.fixedSize(horizontal: false, vertical: true)
      }
    }
  }
}
