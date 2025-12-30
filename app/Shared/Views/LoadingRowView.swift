//
//  LoadingRowView.swift
//  LoadingRowView
//
//  Created by Bugen Zhao on 7/29/21.
//

import Foundation
import SwiftUI

struct LoadingRowView: View {
  let high: Bool

  init(high: Bool = false) {
    self.high = high
  }

  var body: some View {
    HStack {
      Spacer()
      ProgressView()
        .controlSize(high ? .large : .regular)
      Spacer()
    }.frame(minHeight: high ? 80 : 0)
  }
}
