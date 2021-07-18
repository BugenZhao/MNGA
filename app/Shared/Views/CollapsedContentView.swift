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
      Button(action: { withAnimation(.spring()) { self.collapsed.toggle() } }) {
        HStack {
          Image(systemName: self.collapsed ? "eye.slash" : "eye.fill")
          Text(self.title)
        } .padding(.bottom, 1)
          .foregroundColor(.accentColor)
          .font(.subheadline.bold())
      } .buttonStyle(PlainButtonStyle())

      self.content()
        .redacted(reason: self.collapsed ? .placeholder : [])
        .allowsHitTesting(!self.collapsed)
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
