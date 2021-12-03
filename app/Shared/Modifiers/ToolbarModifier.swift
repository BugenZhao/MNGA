//
//  ToolbarModifier.swift
//  NGA (iOS)
//
//  Created by Bugen Zhao on 7/11/21.
//

import Foundation
import SwiftUI

extension View {
  func toolbarWithFix<Content>(@ToolbarContentBuilder content: () -> Content) -> some View where Content: ToolbarContent {
    toolbar {
      #if os(iOS)
        ToolbarItem(placement: .navigationBarLeading) { Text("") } // fix back button bug for iOS 14
      #endif
      content()
    }
  }
}
