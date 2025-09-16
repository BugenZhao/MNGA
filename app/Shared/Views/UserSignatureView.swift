//
//  UserSignatureView.swift
//  MNGA
//
//  Created by Bugen Zhao on 2021/10/4.
//

import Foundation
import SwiftUI

struct UserSignatureView: View {
  let content: PostContent
  let font: Font
  let color: Color

  var body: some View {
    HStack(alignment: .top) {
      Image(systemName: "signature")
        .foregroundColor(.accentColor)
        .imageScale(.small)
      PostContentView(content: content, fontSize: .small, defaultColor: color)
    }
  }
}
