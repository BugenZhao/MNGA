//
//  CacheView.swift
//  CacheView
//
//  Created by Bugen Zhao on 7/28/21.
//

import Foundation
import SwiftUI
import SDWebImage

struct CacheRowView: View {
  let text: LocalizedStringKey
  let size: UInt?
  let clear: () -> Void

  var body: some View {
    Button(action: self.clear) {
      HStack {
        Text(text)
          .foregroundColor(.primary)
        Spacer()
        if let size = self.size {
          Text(ByteCountFormatter().string(fromByteCount: Int64(size)))
            .foregroundColor(.secondary)
        } else {
          ProgressView()
        }
      }
    }
  }
}

struct CacheView: View {
  @State var imageSize = nil as UInt?
  
  @ViewBuilder
  var list: some View {
    List {
      CacheRowView(text: "Image Cache", size: imageSize) {
        self.imageSize = nil
        SDImageCache.shared.clearDisk {
          loadImageSize()
          HapticUtils.play(type: .success)
        }
      } .onAppear { if imageSize == nil { loadImageSize() } }
    }
  }

  var body: some View {
    list
      .listStyle(.insetGrouped)
      .navigationTitle("Cache")
  }
  
  func loadImageSize() {
    SDImageCache.shared.calculateSize { fileCount, totalSize in
      self.imageSize = totalSize
    }
  }
}
