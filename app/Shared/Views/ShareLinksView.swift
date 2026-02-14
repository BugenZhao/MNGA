//
//  ShareLinksView.swift
//  MNGA
//
//  Created by Bugen Zhao on 2021/11/19.
//

import Foundation
import SwiftUI

struct ShareLinksView<V: View>: View {
  let navigationID: NavigationIdentifier
  let shareTitle: String?
  let viewScreenshot: (() -> Void)?
  @ViewBuilder let others: () -> V

  init(
    navigationID: NavigationIdentifier,
    shareTitle: String? = nil,
    viewScreenshot: (() -> Void)? = nil,
    @ViewBuilder others: @escaping () -> V = { EmptyView() },
  ) {
    self.navigationID = navigationID
    self.shareTitle = shareTitle
    self.viewScreenshot = viewScreenshot
    self.others = others
  }

  var normalizedShareTitle: String? {
    guard let shareTitle else { return nil }
    let normalized = shareTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    return normalized.isEmpty ? nil : normalized
  }

  func prefixedShareTitle(_ prefix: String) -> String? {
    guard let title = normalizedShareTitle else { return nil }
    return "\(prefix)\(title)"
  }

  var body: some View {
    Menu {
      if let mngaURL = navigationID.mngaURL {
        if let title = prefixedShareTitle("MNGA - ") {
          ShareLink(item: mngaURL, message: Text(title)) {
            Label("MNGA Link", systemImage: "m.circle")
          }
        } else {
          ShareLink(item: mngaURL) {
            Label("MNGA Link", systemImage: "m.circle")
          }
        }
      }

      if let webpageURL = navigationID.webpageURL {
        if let title = prefixedShareTitle("NGA - ") {
          ShareLink(item: webpageURL, message: Text(title)) {
            Label("NGA Link", systemImage: "network")
          }
        } else {
          ShareLink(item: webpageURL) {
            Label("NGA Link", systemImage: "network")
          }
        }
      }

      if let viewScreenshot {
        Button(action: { viewScreenshot() }) {
          Label("Screenshot", systemImage: "photo")
        }
      }

      others()

      if let webpageURL = navigationID.webpageURL {
        Divider()
        Button(action: { OpenURLModel.shared.open(url: webpageURL) }) {
          Label("Open in Browser", systemImage: "safari")
        }
      }
    } label: {
      Label("Share", systemImage: "square.and.arrow.up")
    }
  }
}
