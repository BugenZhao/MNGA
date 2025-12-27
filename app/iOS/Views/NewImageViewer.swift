//
//  NewImageViewer.swift
//  NGA (iOS)
//
//  Created by Bugen Zhao on 9/13/25.
//

import Foundation
import LazyPager
import SDWebImageSwiftUI
import SwiftUI

struct ViewingImageView: View {
  let url: URL
  @State var transferable: TransferableImage? = nil
  @StateObject var prefs = PreferencesStorage.shared

  @ViewBuilder
  func shareLink(for t: TransferableImage) -> some View {
    switch t {
    case let .plain(plain):
      ShareLink(item: plain, preview: SharePreview("\(plain.base.previewName) (as JPEG)", image: plain.base.previewImage)) {
        Image(systemName: "square.and.arrow.up")
      }
    case let .file(file):
      ShareLink(item: file, preview: SharePreview(file.base.previewName, image: file.base.previewImage)) {
        Image(systemName: "square.and.arrow.up")
      }
    }
  }

  @ViewBuilder
  var image: some View {
    WebImage(url: url).resizable()
      .onSuccess { image, _, _ in
        let forceFile = self.prefs.alwaysShareImageAsFile
        DispatchQueue.global(qos: .userInitiated).async {
          // In case the constructor is heavy, let's do it in a background thread.
          let transferable = TransferableImage(url: url, image: image, forceFile: forceFile)
          DispatchQueue.main.async {
            self.transferable = transferable
          }
        }
      }
      .indicator(.progress)
      .frame(minWidth: 50) // HACK: ensure progress view has width
      .scaledToFit()
  }

  var body: some View {
    image
      .toolbar {
        ToolbarItem(placement: .bottomBar) {
          if let transferable {
            shareLink(for: transferable)
          } else {
            // Still preparing the image.
            ProgressView()
          }
        }
      }
  }
}

struct NewImageViewer: View {
  @EnvironmentObject var model: ViewingImageModel

  @State var opacity: CGFloat = 1.0

  func dismiss() {
    withAnimation { model.showing = false }
  }

  @ViewBuilder
  var main: some View {
    if let url = model.url {
      // TODO: support multiple images for attachments
      LazyPager(data: [url]) {
        ViewingImageView(url: $0)
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

  var body: some View {
    NavigationStack {
      main
        .toolbar {
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
