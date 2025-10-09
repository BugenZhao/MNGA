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

struct TransferableImage: Transferable {
  let id: UUID
  let image: PlatformImage
  let ext: String
  let url: URL

  init?(image: PlatformImage) {
    id = UUID()
    self.image = image

    ext = switch image.sd_imageFormat {
    // static const SDImageFormat SDImageFormatJPEG      = 0;
    // static const SDImageFormat SDImageFormatPNG       = 1;
    // static const SDImageFormat SDImageFormatGIF       = 2;
    // static const SDImageFormat SDImageFormatTIFF      = 3;
    // static const SDImageFormat SDImageFormatWebP      = 4;
    // static const SDImageFormat SDImageFormatHEIC      = 5;
    // static const SDImageFormat SDImageFormatHEIF      = 6;
    // static const SDImageFormat SDImageFormatPDF       = 7;
    // static const SDImageFormat SDImageFormatSVG       = 8;
    // static const SDImageFormat SDImageFormatBMP       = 9;
    case .JPEG: "jpg"
    case .PNG: "png"
    case .GIF: "gif"
    case .TIFF: "tiff"
    case .webP: "webp"
    case .HEIC: "heic"
    case .HEIF: "heif"
    case .PDF: "pdf"
    case .SVG: "svg"
    case .BMP: "bmp"
    // use a random extension for fallback
    default: "png"
    }

    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("MNGA-\(id.uuidString)")
      .appendingPathExtension(ext)

    try? image.sd_imageData()?.write(to: url, options: .atomic)
    self.url = url
  }

  var previewImage: Image {
    Image(image: image)
  }

  var previewName: String {
    "\(ext.uppercased()) Image"
  }

  static var transferRepresentation: some TransferRepresentation {
    ProxyRepresentation { $0.url }
  }
}

class ViewingImageModel: ObservableObject {
  @Published var view: AnyView?
  @Published var transferable: TransferableImage?
  @Published var showing = false

  func show(image: PlatformImage) {
    withAnimation {
      // TODO: can we obtain imageFormat correctly here?
      self.transferable = TransferableImage(image: image)
      self.view = Image(image: image)
        .resizable()
        .eraseToAnyView()
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
      self.showing = true
    }
  }
}
