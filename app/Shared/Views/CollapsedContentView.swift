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
      Button(action: { self.collapsed.toggle() }) {
        HStack {
          Image(systemName: self.collapsed ? "chevron.down" : "chevron.up")
          Text(self.title)
        } .padding(.bottom, 1)
          .foregroundColor(.accentColor)
          .font(.subheadline.bold())
      } .buttonStyle(PlainButtonStyle())

      Group {
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
    } .fixedSize(horizontal: false, vertical: true)
  }
}


struct CollapsedContentView_Previews: PreviewProvider {
  static var previews: some View {
    List {
      ForEach(1...10, id: \.self) { i in
        VStack(alignment: .leading) {
          Text(String(repeating: "Content \(i) ", count: 20))
          CollapsedContentView(title: "Title") {
            Text(String(repeating: "Collapsed \(i) ", count: 20))
          }
        } .fixedSize(horizontal: false, vertical: true)
      }
    } .environment(\.useRedact, false)
  }
}
