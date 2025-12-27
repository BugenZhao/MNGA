//
//  ContentImageView.swift
//  ContentImageView
//
//  Created by Bugen Zhao on 8/22/21.
//

import Foundation
import SDWebImage
import SDWebImageSwiftUI
import SwiftUI
import SwiftUIX

enum ContentImageScale: String, CaseIterable {
  case small
  case medium
  case fullSize

  var description: LocalizedStringKey {
    switch self {
    case .small:
      "Small"
    case .medium:
      "Medium"
    case .fullSize:
      "Full Size"
    }
  }

  var scale: CGFloat {
    switch self {
    case .small:
      0.5
    case .medium:
      2.0 / 3.0
    case .fullSize:
      1.0
    }
  }
}

struct ContentImageView: View {
  let url: URL
  let onlyThumbs: Bool
  let isOpenSourceStickers: Bool

  @Environment(\.inRealPost) var inRealPost // false when in editor preview
  @Environment(\.colorScheme) private var colorScheme
  @EnvironmentObject var viewingImage: ViewingImageModel

  @EnvironmentObject<AttachmentsModel>.Optional var attachmentsModel
  @EnvironmentObject<PresendAttachmentsModel>.Optional var presendAttachmentsModel

  @StateObject var prefs = PreferencesStorage.shared

  init(url: URL, onlyThumbs: Bool = false) {
    self.url = url
    self.onlyThumbs = onlyThumbs
    isOpenSourceStickers = openSourceStickersNames.contains(url.lastPathComponent)
  }

  @State var frameWidth: CGFloat? = nil
  @State private var shouldRevealLoadedImage = false
  @State private var revealTask: Task<Void, Never>?

  var body: some View {
    if isOpenSourceStickers {
      WebImage(url: url).resizable()
        .indicator(.activity)
        .scaledToFit()
        .frame(width: 50, height: 50)
    } else {
      if onlyThumbs {
        ContentButtonView(icon: "photo", title: Text("View Image"), inQuote: true) { showImage() }
      } else {
        Group {
          if let model = presendAttachmentsModel, let image = model.image(for: url) {
            Image(image: image).resizable()
              .scaledToFit()
              .frame(maxWidth: image.size.width * prefs.postRowImageScale.scale)
          } else {
            WebImage(url: url) { phase in
              if shouldRevealLoadedImage, let image = phase.image {
                image.resizable()
              } else {
                ProgressView()
              }
            }
            .onSuccess { image, _, cacheType in
              frameWidth = image.size.width * prefs.postRowImageScale.scale
              scheduleReveal(cacheType: cacheType)
            }
            .onFailure { logger.error("sdwebimage failed to load image: \(url), error: \($0)") }
            .scaledToFit()
            .frame(maxWidth: frameWidth)
            .onDisappear { revealTask?.cancel() }
          }
        }
        // When switching to background, system will automatically trigger changes to colorScheme.
        // Avoid using an `.if()` here, otherwise we lose the state of WebImage and then lose the scroll offset.
        .colorMultiply(shouldDimImage ? Color(white: 0.7) : Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture(perform: showImage)
      }
    }
  }

  private func scheduleReveal(cacheType: SDImageCacheType) {
    revealTask?.cancel()

    if cacheType == .memory {
      shouldRevealLoadedImage = true
      return
    }

    revealTask = Task { @MainActor in
      try? await Task.sleep(for: .seconds(0.3))
      if Task.isCancelled { return }
      shouldRevealLoadedImage = true
    }
  }

  func showImage() {
    guard inRealPost else { return }
    // Use multi-page view if we can find it in attachments.
    if let model = attachmentsModel, let attachURL = model.attachmentURL(for: url) {
      viewingImage.show(urls: model.allImageURLs, current: attachURL)
    } else {
      viewingImage.show(url: url)
    }
  }

  private var shouldDimImage: Bool {
    colorScheme == .dark && PreferencesStorage.shared.postRowDimImagesInDarkMode
  }
}
