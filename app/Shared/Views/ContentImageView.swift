//
//  ContentImageView.swift
//  ContentImageView
//
//  Created by Bugen Zhao on 8/22/21.
//

import Foundation
import SwiftUI
import SDWebImageSwiftUI

struct ContentImageView: View {
  let url: URL
  let onlyThumbs: Bool
  let isOpenSourceStickers: Bool

  @EnvironmentObject var viewingImage: ViewingImageModel

  init(url: URL, onlyThumbs: Bool = false) {
    self.url = url
    self.onlyThumbs = onlyThumbs
    self.isOpenSourceStickers = openSourceStickersNames.contains(url.lastPathComponent)
  }

  var body: some View {
    if isOpenSourceStickers {
      WebImage(url: url)
        .resizable()
        .indicator(.activity)
        .aspectRatio(contentMode: .fit)
        .frame(width: 50, height: 50)
    } else {
      if onlyThumbs {
        ContentButtonView(icon: "photo", title: Text("View Image"), inQuote: true) { self.showImage() }
      } else {
        WebImage(url: url)
          .resizable()
          .indicator(.activity)
          .scaledToFit()
          .clipShape(RoundedRectangle(cornerRadius: 8))
          .onTapGesture(perform: self.showImage)
      }
    }
  }

  func showImage() {
    self.viewingImage.show(url: url)
  }
}
