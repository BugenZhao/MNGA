//
//  ImageOverlay.swift
//  NGA (macOS)
//
//  Created by Bugen Zhao on 7/11/21.
//

import Foundation
import SwiftUI

struct ImageOverlay: View {
  @EnvironmentObject var model: ViewingImageModel

  @ViewBuilder
  var shareMenu: some View {
    if let data = model.imageData, let image = NSImage(data: data) {
      ShareMenuInner(items: [image as Any])
    }
  }

  var body: some View {
    if let view = model.view {
      view
        .aspectRatio(contentMode: .fit)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.12, green: 0.12, blue: 0.12, opacity: 0.9))
        .zIndex(1)
        .transition(AnyTransition.opacity.animation(.easeInOut(duration: 0.2)))
        .onTapGesture { withAnimation { model.view = nil } }
        .contextMenu { shareMenu }
    }
  }
}
