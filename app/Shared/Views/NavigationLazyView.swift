//
//  NavigationLazyView.swift
//  NGA
//
//  Created by Bugen Zhao on 6/28/21.
//

import SwiftUI

struct NavigationLazyView<Content: View>: View {
  let build: () -> Content
  init(_ build: @autoclosure @escaping () -> Content) {
    self.build = build
  }
  var body: Content {
    build()
  }
}
