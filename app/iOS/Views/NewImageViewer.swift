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

  func dismiss() {
    withAnimation { model.showing = false }
  }

  @ViewBuilder
  var main: some View {
    if let view = model.view {
      // TODO: support multiple images for attachments
      LazyPager(data: [view]) { view in
        view.scaledToFit()
      }
      // Make the content zoomable
      .zoomable(min: 1, max: 5)
      // Enable the swipe to dismiss gesture and background opacity control
      .onDismiss(backgroundOpacity: $opacity) { dismiss() }
      // Set the background color with the drag opacity control
      .background(.black)
      // A special included modifier to help make fullScreenCover transparent
      .background(ClearFullScreenBackground())
      // Works with safe areas or ignored safe areas
      .ignoresSafeArea()
    }
  }

  @ViewBuilder
  func shareLink(for t: TransferableImage) -> some View {
    switch t {
    case let .plain(plain):
      ShareLink(item: plain, preview: SharePreview("\(plain.base.previewName) (Plain)", image: plain.base.previewImage)) {
        Image(systemName: "square.and.arrow.up")
      }
    case let .file(file):
      ShareLink(item: file, preview: SharePreview(file.base.previewName, image: file.base.previewImage)) {
        Image(systemName: "square.and.arrow.up")
      }
    }
  }

  var body: some View {
    NavigationStack {
      main
        .toolbar {
          ToolbarItem(placement: .bottomBar) {
            if let t = model.transferable {
              shareLink(for: t)
            } else {
              // Still preparing the image.
              ProgressView()
            }
          }

          ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: dismiss) {
              Image(systemName: "xmark")
            }
          }
        }
        .navigationTitleInline(key: "")
    }
    .opacity(opacity)
    .background(ClearFullScreenBackground())
  }
}
