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
import UniformTypeIdentifiers

extension URL {
  var hashedFilename: String {
    let data = Data(absoluteString.utf8)
    let digest = Insecure.MD5.hash(data: data)
    return digest.map { String(format: "%02hhx", $0) }.joined()
  }
}

extension PlatformImage {
  var utType: UTType? {
    switch sd_imageFormat {
    case .JPEG: .jpeg
    case .PNG: .png
    case .GIF: .gif
    case .TIFF: .tiff
    case .webP: .webP
    case .HEIC: .heic
    case .HEIF: .heif
    case .PDF: .pdf
    case .SVG: .svg
    case .BMP: .bmp
    default: nil
    }
  }

  // TODO: for plain image, prefer proxying to `Image`, instead of using `FileRepresentation`
  var isPlainImage: Bool {
    if sd_isAnimated { return false }

    switch utType {
    case .jpeg, .png, .webP: return true
    default: return false
    }
  }
}

struct TransferableImage: Transferable {
  let image: PlatformImage
  let imageData: Data
  let utType: UTType
  let url: URL

  init?(url: URL, image: PlatformImage) {
    self.image = image
    self.url = url

    guard let imageData = image.sd_imageData() else { return nil }
    self.imageData = imageData

    guard let utType = image.utType else { return nil }
    self.utType = utType
  }

  var previewImage: Image {
    Image(image: image)
  }

  var previewName: String {
    "\(utType.localizedDescription, default: "Image".localized) @ MNGA"
  }

  static var transferRepresentation: some TransferRepresentation {
    FileRepresentation(exportedContentType: .data) {
      let tempURL = FileManager.default.temporaryDirectory
        // This method will check the extension from given name and attach the right extension if needed.
        .appendingPathComponent("MNGA_\($0.url.hashedFilename)_\($0.url.lastPathComponent)", conformingTo: $0.utType)

      if !FileManager.default.fileExists(atPath: tempURL.path) {
        try $0.imageData.write(to: tempURL, options: .atomic)
      }
      return SentTransferredFile(tempURL)
    }
  }
}

class ViewingImageModel: ObservableObject {
  @Published var view: AnyView?
  @Published var transferable: TransferableImage?
  @Published var showing = false

  func show(url: URL) {
    transferable = nil
    view = WebImage(url: url).resizable()
      .onSuccess { image, _, _ in
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
          // The constructor will decode image data, which might be expensive.
          // So we do it in a background thread.
          let transferable = TransferableImage(url: url, image: image)
          DispatchQueue.main.async {
            self?.transferable = transferable
          }
        }
      }
      .indicator(.progress)
      .frame(minWidth: 50) // HACK: ensure progress view has width
      .eraseToAnyView()

    withAnimation { showing = true }
  }
}
