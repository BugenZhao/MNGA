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
  @Binding var transferable: TransferableImage?
  @StateObject var prefs = PreferencesStorage.shared

  var body: some View {
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
}

struct NewImageViewer: View {
  @EnvironmentObject var model: ViewingImageModel

  @State var opacity: CGFloat = 1.0

  func dismiss() {
    withAnimation { model.showing = false }
  }

  @ViewBuilder
  var main: some View {
    if !model.urls.isEmpty {
      LazyPager(data: Array(model.urls.enumerated()), page: $model.currentIndex) { index, url in
        ViewingImageView(url: url, transferable: $model.transferables[index])
      }
      // Add some spacing between pages so it looks like the system album
      .pageSpacing(40)
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
  var pageIndicator: some View {
    if model.urls.count > 1 {
      HStack(alignment: .bottom, spacing: 4) {
        Text("\(model.currentIndex + 1)")
        Text("/ \(model.urls.count)")
          .foregroundColor(.secondary)
          .font(.footnote)
      }
      .padding(.horizontal, 10)
      .fixedSize()
      .monospacedDigit()
    }
  }

  var body: some View {
    NavigationStack {
      main
        .toolbar {
          ToolbarItem(placement: .bottomBar) { pageIndicator }
          MaybeToolbarSpacer(placement: .bottomBar)
          ToolbarItem(placement: .bottomBar) {
            if let transferable = model.transferables[model.currentIndex] {
              shareLink(for: transferable)
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
}
