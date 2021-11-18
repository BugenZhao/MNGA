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

  let mnga: URL?
  let nga: URL?
  @ViewBuilder let others: () -> V

  var body: some View {
    Menu {
      Button(action: { self.activity.put(mnga) }) {
        Label("MNGA Link", systemImage: "m.circle")
      }
      Button(action: { self.activity.put(nga) }) {
        Label("NGA Link", systemImage: "network")
      }
      if let o = others { o() }
    } label: {
      Label("Share...", systemImage: "square.and.arrow.up")
    }
  }
}
