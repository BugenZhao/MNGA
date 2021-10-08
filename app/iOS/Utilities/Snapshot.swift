//
//  Snapshot.swift
//  Snapshot
//
//  Created by Bugen Zhao on 8/16/21.
//

import Foundation
import SwiftUI
import SwiftUIX

extension View {
  func snapshot() -> AppKitOrUIKitImage {
    let controller = UIHostingController(rootView: self)
    guard let view = controller.view else { return UIImage() }

    let targetSize = controller.view.intrinsicContentSize
    view.bounds = CGRect(origin: .zero, size: targetSize)
    view.backgroundColor = .clear

    let format = UIGraphicsImageRendererFormat()
    format.scale = 2.0
    let renderer = UIGraphicsImageRenderer(bounds: view.bounds, format: format)
    
    return renderer.image { _ in
      view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
    }
  }
}
