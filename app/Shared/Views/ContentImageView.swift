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

struct ContentImageView: View {
  let url: URL
  let onlyThumbs: Bool
  let isOpenSourceStickers: Bool

  @Environment(\.inRealPost) var inRealPost
  @EnvironmentObject var viewingImage: ViewingImageModel

  @OptionalEnvironmentObject<AttachmentsModel> var attachmentsModel
  @OptionalEnvironmentObject<PresendAttachmentsModel> var presendAttachmentsModel

  init(url: URL, onlyThumbs: Bool = false) {
    self.url = url
    self.onlyThumbs = onlyThumbs
    isOpenSourceStickers = openSourceStickersNames.contains(url.lastPathComponent)
  }

  var body: some View {
    if isOpenSourceStickers {
      WebOrAsyncImage(url: url, placeholder: nil)
        .aspectRatio(contentMode: .fit)
        .frame(width: 50, height: 50)
    } else {
      if onlyThumbs {
        ContentButtonView(icon: "photo", title: Text("View Image"), inQuote: true) { self.showImage() }
      } else {
        Group {
          if let model = presendAttachmentsModel, let image = model.image(for: url) {
            Image(image: image)
              .resizable()
          } else {
            WebOrAsyncImage(url: url, placeholder: nil)
          }
        }.scaledToFit()
          .clipShape(RoundedRectangle(cornerRadius: 8))
          .onTapGesture(perform: self.showImage)
      }
    }
  }

  func showImage() {
    guard inRealPost else { return }
    let attachURL = attachmentsModel?.attachmentURL(for: url) ?? url
    viewingImage.show(url: attachURL)
  }
}
