//
//  AttachmentsView.swift
//  MNGA
//
//  Created by Bugen Zhao on 2021/11/21.
//

import Foundation
import SwiftUI
import BetterSafariView
import SwiftUIX

struct AttachmentsView: View {
  @OptionalEnvironmentObject<ViewingImageModel> var image
  @ObservedObject var model: AttachmentsModel

  @Environment(\.presentationMode) var presentation

  func image(for attachment: Attachment) -> String {
    switch attachment.type {
    case "img":
      return "photo"
    default:
      return "link"
    }
  }

  var body: some View {
    List {
      ForEachOrEmpty(model.items, id: \.url) { attachment in
        Button(action: { self.show(attachment) }) {
          Label(attachment.url, systemImage: image(for: attachment))
            .font(.system(.subheadline, design: .monospaced))
            .lineLimit(1)
            .truncationMode(.middle)
        }
          .buttonStyle(.plain)
      }
    }
      .navigationTitle("Attachments")
  }

  func show(_ attachment: Attachment) {
    let url = URL(string: attachment.url, relativeTo: URLs.attachmentBase)
    guard let url = url else { return }

    if attachment.type == "img" {
      image?.show(url: url)
    } else {
      OpenURLModel.shared.open(url: url, inApp: true)
    }
  }
}
