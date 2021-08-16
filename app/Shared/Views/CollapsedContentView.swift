//
//  CollapsedContentView.swift
//  NGA
//
//  Created by Bugen Zhao on 7/13/21.
//

import Foundation
import SwiftUI

struct UseRedactKey: EnvironmentKey {  
  static let defaultValue: Bool = true
}

extension EnvironmentValues {
  var useRedact: Bool {
    get { self[UseRedactKey.self] }
    set { self[UseRedactKey.self] = newValue }
  }
}

struct CollapsedContentView<Content: View>: View {
  let title: String
  @ViewBuilder let content: () -> Content

  @Environment(\.useRedact) var useRedact

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

      if useRedact {
        self.content()
          .redacted(if: self.collapsed)
          .allowsHitTesting(!self.collapsed)
      } else {
        if !self.collapsed {
          self.content()
        }
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
