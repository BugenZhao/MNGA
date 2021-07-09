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
  @Published var imageView: Image?

  private(set) var image: PlatformImage? {
    didSet { self.imageView = image == nil ? nil : Image(image: image!) }
  }

  @Published var isShowing = false

  func show(image: PlatformImage?) {
    self.image = image
    self.isShowing = image != nil
  }
}
