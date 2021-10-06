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
    let controller = AppKitOrUIKitHostingController(rootView: self)
    let view = controller.view

    let targetSize = controller.view.intrinsicContentSize
    view?.bounds = CGRect(origin: .zero, size: targetSize)
    view?.backgroundColor = .clear

    let renderer = UIGraphicsImageRenderer(size: targetSize)

    return renderer.image { _ in
      view?.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
    }
  }
}
