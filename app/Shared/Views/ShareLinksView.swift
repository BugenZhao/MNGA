//
//  ShareLinksView.swift
//  MNGA
//
//  Created by Bugen Zhao on 2021/11/19.
//

import Foundation
import SwiftUI

struct ShareLinksView<V: View>: View {
  @EnvironmentObject var activity: ActivityModel

  let navigationID: NavigationIdentifier
  @ViewBuilder let others: () -> V

  var body: some View {
    Menu {
      Button(action: { activity.put(navigationID.mngaURL) }) {
        Label("MNGA Link", systemImage: "m.circle")
      }

      if !navigationID.isMNGAMockID {
        Button(action: { activity.put(navigationID.webpageURL) }) {
          Label("NGA Link", systemImage: "network")
        }
      }

      others()
    } label: {
      Label("Share", systemImage: "square.and.arrow.up")
    }
  }
}
