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
  @ViewBuilder let others: () -> V

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
