//
//  SharedFromMNGAView.swift
//  MNGA
//
//  Created by Bugen Zhao on 2021/10/8.
//

import Foundation
import SwiftUI

struct SharedFromMNGAView: View {
  var body: some View {
    HStack(spacing: 8) {
      Spacer()
      Text("Shared from")
        .foregroundColor(.secondary)
      Image("RoundedIcon").resizable().frame(width: 24, height: 24)
      Text("MNGA")
        .fontWeight(.bold)
        .font(.title3)
    }
  }
}

struct SharedFromMNGAView_Previews: PreviewProvider {
  static var previews: some View {
    SharedFromMNGAView()
      .padding()
      .background(Color.black.opacity(0.1))
  }
}
