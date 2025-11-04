//
//  ContentImageView.swift
//  ContentImageView
//
//  Created by Bugen Zhao on 8/22/21.
//

import Foundation
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

  @Environment(\.inRealPost) var inRealPost
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
            WebImage(url: url).resizable()
              .onSuccess { image, _, _ in frameWidth = image.size.width * prefs.postRowImageScale.scale }
              .indicator(.activity)
              .scaledToFit()
              .frame(maxWidth: frameWidth)
          }
        }
        .if(shouldDimImage) { $0.colorMultiply(Color(white: 0.7)) }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture(perform: showImage)
      }
    }
  }

  func showImage() {
    guard inRealPost else { return }
    let attachURL = attachmentsModel?.attachmentURL(for: url) ?? url
    viewingImage.show(url: attachURL)
  }

  private var shouldDimImage: Bool {
    colorScheme == .dark && PreferencesStorage.shared.postRowDimImagesInDarkMode
  }
}
