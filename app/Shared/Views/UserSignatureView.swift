//
//  UserSignatureView.swift
//  MNGA
//
//  Created by Bugen Zhao on 2021/10/4.
//

import Foundation
import SwiftUI

struct UserSignatureView: View {
  let spans: [Span]
  let font: Font
  let color: Color

  var body: some View {
    HStack(alignment: .top) {
      Image(systemName: "signature")
        .foregroundColor(.accentColor)
        .imageScale(.small)
      PostContentView(spans: spans, defaultFont: font, defaultColor: color)
        .equatable()
        .environment(\.useRedact, false)
    }
  }
}
