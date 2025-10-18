//
//  ViewingImageModel.swift
//  NGA
//
//  Created by Bugen Zhao on 7/7/21.
//

import Combine
import CryptoKit
import Foundation
import SDWebImageSwiftUI
import SwiftUI
import SwiftUIX

extension URL {
  var hashedFilename: String {
    let data = Data(absoluteString.utf8)
    let digest = Insecure.MD5.hash(data: data)
    return digest.map { String(format: "%02hhx", $0) }.joined()
  }
}

struct TransferableImage: Transferable {
  let image: PlatformImage
  let ext: String
  let url: URL
  let localURL: URL

  init?(url: URL, image: PlatformImage) {
    self.image = image
    self.url = url

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

    localURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("MNGA-\(url.hashedFilename)")
      .appendingPathExtension(ext)

    if !FileManager.default.fileExists(atPath: localURL.path) {
      try? image.sd_imageData()?.write(to: localURL, options: .atomic)
    }
  }

  var previewImage: Image {
    Image(image: image)
  }

  var previewName: String {
    "\(ext.uppercased()) Image (\(url.lastPathComponent))"
  }

  static var transferRepresentation: some TransferRepresentation {
    ProxyRepresentation { $0.localURL }
  }
}

class ViewingImageModel: ObservableObject {
  @Published var view: AnyView?
  @Published var transferable: TransferableImage?
  @Published var showing = false

  func show(url: URL) {
    view = WebImage(url: url)
      .onSuccess { image, _, _ in
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
          let transferable = TransferableImage(url: url, image: image)
          DispatchQueue.main.sync {
            self?.transferable = transferable
          }
        }
      }
      .resizable()
      .indicator(.progress)
      .eraseToAnyView()

    withAnimation { showing = true }
  }
}
