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
  @Published var id: UUID?
  @Published var view: AnyView?
  @Published var imageData: Data?
  @Published var showing = false

  func show(image: PlatformImage) {
    withAnimation {
      self.imageData = image.sd_imageData()
      self.view = Image(image: image)
        .resizable()
        .eraseToAnyView()
      self.id = UUID()
      self.showing = true
    }
  }

  func show(url: URL) {
    withAnimation {
      self.imageData = nil
      self.view = WebImage(url: url)
        .onSuccess { image, _, _ in
          DispatchQueue.main.async {
            self.imageData = image.sd_imageData()
          }
        }
        .resizable()
        .indicator(.progress)
        .eraseToAnyView()
      self.id = UUID()
      self.showing = true
    }
  }
}
