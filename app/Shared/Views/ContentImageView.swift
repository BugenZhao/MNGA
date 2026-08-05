//
//  ContentImageView.swift
//  ContentImageView
//
//  Created by Bugen Zhao on 8/22/21.
//

import Foundation
import Photos
import SDWebImageSwiftUI
import SwiftUI
import SwiftUIX

extension EnvironmentValues {
  @Entry var contentImageForceNotThumb: Bool = false
}

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
  @Environment(\.inSnapshot) var inSnapshot
  @Environment(\.contentImageForceNotThumb) var contentImageForceNotThumb
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
  @State private var quickSaveDialogPresented = false

  var options: SDWebImageOptions {
    if inSnapshot {
      // Ensure we have the image loaded synchronously to correctly render in snapshot.
      [.queryDiskDataSync, .queryMemoryDataSync]
    } else {
      []
    }
  }

  var body: some View {
    if isOpenSourceStickers {
      WebImage(url: url).resizable()
        .indicator(.activity)
        .scaledToFit()
        .frame(width: 50, height: 50)
    } else {
      if onlyThumbs, !contentImageForceNotThumb {
        ContentButtonView(icon: "photo", title: Text("View Image"), inQuote: true) { showImage() }
      } else {
        Group {
          if let model = presendAttachmentsModel, let image = model.image(for: url) {
            Image(image: image).resizable()
              .scaledToFit()
              .frame(maxWidth: image.size.width * prefs.postRowImageScale.scale)
          } else {
            WebImage(url: url, options: options).resizable()
              .onSuccess { image, _, _ in frameWidth = image.size.width * prefs.postRowImageScale.scale }
              .onFailure { logger.error("sdwebimage failed to load image: \(url), error: \($0)") }
              .indicator(.activity)
              .scaledToFit()
              .frame(maxWidth: frameWidth)
          }
        }
        // When switching to background, system will automatically trigger changes to colorScheme.
        // Avoid using an `.if()` here, otherwise we lose the state of WebImage and then lose the scroll offset.
        .colorMultiply(shouldDimImage ? Color(white: 0.7) : Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture(perform: showImage)
        // Use a high-priority long press so the image can present its own quick
        // actions instead of being swallowed by the post-level `.contextMenu`.
        // The gesture mask disables it when the preference is off, leaving the
        // post-level context menu intact. Avoid `.if()` here to keep WebImage state.
        .highPriorityGesture(
          LongPressGesture(minimumDuration: 0.4)
            .onEnded { _ in quickSaveDialogPresented = true },
          including: prefs.quickSaveImage && inRealPost ? .all : .none,
        )
        .confirmationDialog("Image", isPresented: $quickSaveDialogPresented, titleVisibility: .hidden) {
          Button("Save to Photos") { saveImageToPhotos() }
          Button("View Image") { showImage() }
        }
      }
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

  func saveImageToPhotos() {
    SDWebImageManager.shared.loadImage(with: url, options: [], progress: nil) { image, data, _, _, _, _ in
      guard let image else {
        ToastModel.showAuto(.error("Save Failed"))
        return
      }
      PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
        guard status == .authorized || status == .limited else {
          DispatchQueue.main.async {
            ToastModel.showAuto(.error("No Photo Library Permission"))
          }
          return
        }
        PHPhotoLibrary.shared().performChanges {
          if let data {
            let options = PHAssetResourceCreationOptions()
            options.originalFilename = url.lastPathComponent
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, data: data, options: options)
          } else {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
          }
        } completionHandler: { success, _ in
          DispatchQueue.main.async {
            if success {
              ToastModel.showAuto(.success("Saved"))
            } else {
              ToastModel.showAuto(.error("Save Failed"))
            }
          }
        }
      }
    }
  }

  private var shouldDimImage: Bool {
    colorScheme == .dark && PreferencesStorage.shared.postRowDimImagesInDarkMode
  }
}
