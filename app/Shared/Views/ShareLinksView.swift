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
  let viewScreenshot: (() -> Void)?
  @ViewBuilder let others: () -> V

  init(
    navigationID: NavigationIdentifier,
    viewScreenshot: (() -> Void)? = nil,
    @ViewBuilder others: @escaping () -> V = { EmptyView() },
  ) {
    self.navigationID = navigationID
    self.viewScreenshot = viewScreenshot
    self.others = others
  }

  var body: some View {
    Menu {
      if let mngaURL = navigationID.mngaURL {
        ShareLink(item: mngaURL) {
          Label("MNGA Link", systemImage: "m.circle")
        }
      }

      if let webpageURL = navigationID.webpageURL {
        ShareLink(item: webpageURL) {
          Label("NGA Link", systemImage: "network")
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
