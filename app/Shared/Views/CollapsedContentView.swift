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
      Button(action: { withAnimation { self.collapsed.toggle() } }) {
        HStack {
          Image(systemName: self.collapsed ? "chevron.down" : "chevron.up")
          Text(self.title)
        } .padding(.bottom, 1)
          .foregroundColor(.accentColor)
          .font(.subheadline.bold())
      } .buttonStyle(PlainButtonStyle())

      if !self.collapsed {
        self.content()
          .transition(.move(edge: .top).combined(with: .opacity))
      }
    }
  }
}


struct CollapsedContentView_Previews: PreviewProvider {
  static var previews: some View {
    CollapsedContentView(title: "Title") {
      PostContentView_Previews.previews
    }
  }
}
