//
//  ShareMenu.swift
//  MNGA (macOS)
//
//  Created by Bugen Zhao on 2021/10/6.
//

import Foundation
import SwiftUI

struct ShareMenuInner: View {
  let items: [Any]

  var body: some View {
    if let item = items.first {
      Button(action: { copyToPasteboard(item) }) {
        Image(systemName: "doc.on.doc")
        Text("Copy")
      }
      if let url = item as? URL {
        Button(action: { OpenURLModel.shared.open(url: url) }) {
          Image(systemName: "safari")
          Text("Open in Browser")
        }
      }
    }
    ForEach(NSSharingService.sharingServices(forItems: items), id: \.title) { item in
      Button(action: { item.perform(withItems: items) }) {
        Image(nsImage: item.image)
        Text(item.title)
      }
    }
  }
}

struct ShareMenu: View {
  let items: [Any]

  var body: some View {
    Menu(content: { ShareMenuInner(items: items) }) {
      Label("Share", systemImage: "square.and.arrow.up")
    }
  }
}
