//
//  ToolbarModifier.swift
//  NGA (iOS)
//
//  Created by Bugen Zhao on 7/11/21.
//

import Foundation
import SwiftUI

struct SingleItemToolbarModifier<M: View>: ViewModifier {
  let build: () -> M

  func body(content: Content) -> some View {
    content
    #if os(iOS)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) { Text("") } // fix back button bug for iOS 14
        ToolbarItem(placement: .navigationBarTrailing, content: build)
      }
    #elseif os(macOS)
      .toolbar {
        ToolbarItem(content: build)
      }
    #endif
  }
}

struct DoubleItemsToolbarModifier<M1: View, M2: View>: ViewModifier {
  let buildLeading: () -> M1
  let buildTrailing: () -> M2

  func body(content: Content) -> some View {
    content
    #if os(iOS)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading, content: buildLeading)
        ToolbarItem(placement: .navigationBarTrailing, content: buildTrailing)
      }
    #elseif os(macOS)
      .toolbar {
        ToolbarItem(content: buildLeading)
        ToolbarItem(content: buildTrailing)
      }
    #endif
  }
}
