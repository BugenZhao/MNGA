//
//  Snapshot.swift
//  Snapshot
//
//  Created by Bugen Zhao on 8/16/21.
//

import Foundation
import SwiftUI
import SwiftUIX

extension EnvironmentValues {
  @Entry var inSnapshot: Bool = false
}

extension View {
  /// Renders the view into an image file and returns its temporary file URL.
  ///
  /// This uses SwiftUI's `ImageRenderer` so it can render SwiftUI primitives (text, shapes, images, etc.).
  /// Note that some UIKit-backed views (like web views and media players) may be rendered as placeholders.
  @MainActor
  func snapshot() -> URL? {
    let renderer = ImageRenderer(content:
      `self`
        .environment(\.inSnapshot, true))
    renderer.scale = Screen.main.scale
    renderer.isOpaque = true

    guard let image = renderer.uiImage else { return nil }

    let fileName = "MNGA_Snapshot_\(UUID().uuidString).jpg"
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

    guard let data = image.jpegData(compressionQuality: 0.9) else { return nil }
    do {
      try data.write(to: url, options: .atomic)
      return url
    } catch {
      return nil
    }
  }
}
