//
//  ViewingImageModel.swift
//  NGA
//
//  Created by Bugen Zhao on 7/7/21.
//

import Foundation
import Combine
import SwiftUI
import SwiftUIX
import SDWebImageSwiftUI

class ViewingImageModel: ObservableObject {
  @Published var view: AnyView?
  @Published var image: PlatformImage?

  func show(image: PlatformImage) {
    withAnimation {
      self.view = Image(image: image)
        .resizable()
        .eraseToAnyView()
      self.image = image
    }
  }

  func show(url: URL) {
    withAnimation {
      self.view = WebImage(url: url)
        .onSuccess { image, _, _ in
        DispatchQueue.main.async {
          self.image = image
        }
      }
        .resizable()
        .indicator(.progress)
        .eraseToAnyView()
      self.image = nil
    }
  }
}
