//
//  NewImageViewer.swift
//  NGA (iOS)
//
//  Created by Bugen Zhao on 9/13/25.
//

import Foundation
import LazyPager
import SwiftUI

struct NewImageViewer: View {
  @EnvironmentObject var model: ViewingImageModel

  @State var opacity: CGFloat = 1.0

  @ViewBuilder
  var main: some View {
    if let view = model.view {
      // TODO: support multiple images for attachments
      LazyPager(data: [view]) { view in
        view.aspectRatio(contentMode: .fit)
      }
      // Make the content zoomable
      .zoomable(min: 1, max: 5)
      // Enable the swipe to dismiss gesture and background opacity control
      .onDismiss(backgroundOpacity: $opacity) {
        withAnimation { model.showing = false }
      }
      // Set the background color with the drag opacity control
      .background(.black)
      // A special included modifier to help make fullScreenCover transparent
      .background(ClearFullScreenBackground())
      // Works with safe areas or ignored safe areas
      .ignoresSafeArea()
    }
  }

  var body: some View {
    NavigationView {
      main
        .toolbar {
          if let data = model.imageData,
             let id = model.id,
             let image = Image(data: data)
          {
            ToolbarItem(placement: .bottomBar) {
              ShareLink(item: image, preview: SharePreview("\(id)", image: image)) {
                Image(systemName: "square.and.arrow.up")
              }
            }
          }
        }
        .navigationTitleInline(key: "")
    }
    .opacity(opacity)
    .background(ClearFullScreenBackground())
    .id(model.id)
  }
}
