//
//  AttachmentsView.swift
//  MNGA
//
//  Created by Bugen Zhao on 2021/11/21.
//

import BetterSafariView
import Foundation
import SwiftUI
import SwiftUIX

struct AttachmentsView: View {
  @EnvironmentObject<ViewingImageModel>.Optional var image
  @ObservedObject var model: AttachmentsModel

  @Binding var isPresented: Bool

  func image(for attachment: Attachment) -> String {
    switch attachment.type {
    case "img":
      "photo"
    default:
      "link"
    }
  }

  var body: some View {
    List {
      ForEachOrEmpty(model.items, id: \.url) { attachment in
        Button(action: { show(attachment) }) {
          Label(attachment.url, systemImage: image(for: attachment))
            .font(.system(.subheadline, design: .monospaced))
            .lineLimit(1)
            .truncationMode(.middle)
        }
        .buttonStyle(.plain)
      }
    }
    .navigationTitleInline(key: "Attachments")
  }

  var allImageURLs: [URL] {
    model.items
      .filter { $0.isImage }
      .compactMap { URL(string: $0.url, relativeTo: URLs.attachmentBase) }
  }

  func show(_ attachment: Attachment) {
    let url = URL(string: attachment.url, relativeTo: URLs.attachmentBase)
    guard let url else { return }

    if attachment.isImage {
      isPresented = false // dismiss sheet first, otherwise the background will be black
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { // workaround image viewer background
        image?.show(urls: allImageURLs, current: url)
      }
    } else {
      OpenURLModel.shared.open(url: url, inApp: true)
    }
  }
}
