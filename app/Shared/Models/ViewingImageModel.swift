//
//  ViewingImageModel.swift
//  NGA
//
//  Created by Bugen Zhao on 7/7/21.
//

import Combine
import Foundation
import SDWebImageSwiftUI
import SwiftUI
import SwiftUIX

class ViewingImageModel: ObservableObject {
  @Published var view: AnyView? {
    didSet { id = UUID() }
  }

  @Published var id: UUID?
  @Published var imageData: Data?

  func show(image: PlatformImage) {
    withAnimation {
      self.view = Image(image: image)
        .resizable()
        .eraseToAnyView()
      self.imageData = image.sd_imageData()
    }
  }

  func show(url: URL) {
    withAnimation {
      self.view = WebImage(url: url)
        .onSuccess { image, _, _ in
          DispatchQueue.main.async {
            self.imageData = image.sd_imageData()
          }
        }
        .resizable()
        .indicator(.progress)
        .eraseToAnyView()
      self.imageData = nil
    }
  }
}
