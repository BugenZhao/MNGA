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

  var inferredUTType: UTType? {
    guard !pathExtension.isEmpty else { return nil }
    return UTType(filenameExtension: pathExtension)
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

  func isPlainImage(for utType: UTType) -> Bool {
    if sd_isAnimated { return false }
    if cgImage?.alphaInfo ?? .none != .none { return false }

    switch utType {
    // This covers almost all common image formats in use.
    case .jpeg,
         .png,
         .webP: return true
    default: return false
    }
  }
}

// We don't use a single type with `TransferRepresentation.exportingCondition` since it doesn't seem to always work...
// Determine the type ahead of time always works well.
enum TransferableImage {
  // Plain image will be encoded to JPEG and exported as JPEG Data.
  case plain(TransferablePlainImage)
  // File image will be exported as original file.
  case file(TransferableFileImage)

  init?(url: URL, image: PlatformImage, forceFile: Bool) {
    guard let utType = image.utType ?? url.inferredUTType else { return nil }
    let base = TransferableImageBase(image: image, utType: utType, url: url)

    self = if !forceFile, image.isPlainImage(for: utType) {
      .plain(.init(base: base))
    } else {
      .file(.init(base: base))
    }
  }
}

struct TransferableImageBase {
  let image: PlatformImage
  let utType: UTType
  let url: URL

  var previewImage: Image {
    Image(image: image)
  }

  var previewName: String {
    "MNGA \(utType.localizedDescription, default: "Image".localized)"
  }

  var partialName: String {
    "MNGA_\(url.hashedFilename)_\(url.lastPathComponent)"
  }
}

struct TransferableFileImage: Transferable {
  let base: TransferableImageBase

  static var transferRepresentation: some TransferRepresentation {
    FileRepresentation(exportedContentType: .data) {
      let tempURL = FileManager.default.temporaryDirectory
        // This method will check the extension from given name and attach the right extension if needed.
        .appendingPathComponent($0.base.partialName, conformingTo: $0.base.utType)

      if !FileManager.default.fileExists(atPath: tempURL.path) {
        let imageData = $0.base.image.sd_imageData() ?? Data()
        try imageData.write(to: tempURL, options: .atomic)
      }
      return SentTransferredFile(tempURL)
    }
  }
}

struct TransferablePlainImage: Transferable {
  let base: TransferableImageBase

  static var transferRepresentation: some TransferRepresentation {
    DataRepresentation(exportedContentType: .jpeg) {
      $0.base.image.jpegData(compressionQuality: 0.9) ?? Data()
    }
    .suggestedFileName { $0.base.partialName }
  }
}

class ViewingImageModel: ObservableObject {
  @Published var urls: [URL] = []
  @Published var currentIndex = 0
  @Published var showing = false

  func show(url: URL) {
    show(urls: [url], current: url)
  }

  func show(urls: [URL], current: URL) {
    if urls.isEmpty { return }
    self.urls = urls
    currentIndex = urls.firstIndex(of: current) ?? 0
    withAnimation { showing = true }
  }
}
