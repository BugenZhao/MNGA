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

// TODO: webp will be converted to png and lost animation
struct TransferableImage: Transferable {
  let image: PlatformImage

  var previewImage: Image {
    Image(image: image)
  }

  static var transferRepresentation: some TransferRepresentation {
    ProxyRepresentation { Image(image: $0.image) }
  }
}

class ViewingImageModel: ObservableObject {
  @Published var id: UUID?
  @Published var view: AnyView?
  @Published var transferable: TransferableImage?
  @Published var showing = false

  func show(image: PlatformImage) {
    withAnimation {
      self.transferable = TransferableImage(image: image)
      self.view = Image(image: image)
        .resizable()
        .eraseToAnyView()
      self.id = UUID()
      self.showing = true
    }
  }

  func show(url: URL) {
    withAnimation {
      self.view = WebImage(url: url)
        .onSuccess { image, _, _ in
          DispatchQueue.main.async {
            self.transferable = TransferableImage(image: image)
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
