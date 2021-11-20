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
  let status: String?
  let clear: (() -> Void)?

  @State var alertPresented = false

  @ViewBuilder
  var inner: some View {
    HStack {
      Text(text)
        .foregroundColor(clear == nil ? .secondary : .primary)
      Spacer()
      if let status = self.status {
        Text(status)
          .foregroundColor(.secondary)
      } else {
        ProgressView()
      }
    }
  }

  var body: some View {
    Group {
      if let clear = clear {
        Button(action: { self.alertPresented = true }) {
          inner
        } .alert(isPresented: $alertPresented) {
          Alert(title: Text("Are you sure to clear the cache?"), message: Text("This will take a while."), primaryButton: .default(Text("Clear")) { clear() }, secondaryButton: .cancel())
        }
      } else {
        inner
      }
    }
  }
}

struct CacheView: View {
  @State var imageStatus: String?

  @State var cacheStatus = [CacheType: String]()

  @ViewBuilder
  var list: some View {
    List {

      Section(header: Text("Image")) {
        CacheRowView(text: "Image Cache", status: imageStatus) {
          self.imageStatus = nil
          self.clearImageCache()
        } .onAppear { if imageStatus == nil { loadImageCacheSize() } }
      }

      Section(header: Text("Data")) {
        ForEach(CacheType.allCases, id: \.self) { type in
          let action = type == .all ? nil: {
            self.cacheStatus.removeValue(forKey: type)
            self.manipulateCache(for: type, operation: .clear)
          }
          CacheRowView(text: type.description, status: cacheStatus[type], clear: action)
            .onAppear { manipulateCache(for: type, operation: .check) }
        }
      }

    }
  }

  var body: some View {
    list
      .mayInsetGroupedListStyle()
      .navigationTitle("Cache")
  }

  func clearImageCache() {
    SDImageCache.shared.clearDisk {
      loadImageCacheSize()
      #if os(iOS)
        HapticUtils.play(type: .success)
      #endif
    }
  }

  func loadImageCacheSize() {
    SDImageCache.shared.calculateSize { fileCount, totalSize in
      self.imageStatus = ByteCountFormatter().string(fromByteCount: Int64(totalSize))
    }
  }

  func manipulateCache(for type: CacheType, operation: CacheOperation) {
    logicCallAsync(.cache(.with {
      $0.type = type
      $0.operation = operation
    })) { (response: CacheResponse) in
      if type == .all {
        self.cacheStatus[type] = ByteCountFormatter().string(fromByteCount: Int64(response.totalSize))
      } else {
        self.cacheStatus[type] = String(format: "%llu items".localized, response.items)
      }

      if operation == .clear {
        #if os(iOS)
          HapticUtils.play(type: .success)
        #endif
      }
    }
  }
}
