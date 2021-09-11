//
//  QuoteUserView.swift
//  QuoteUserView
//
//  Created by Bugen Zhao on 2021/9/11.
//

import Foundation
import SwiftUI

struct QuoteUserView: View {
  let uid: String
  let action: (() -> Void)?

  var body: some View {
    HStack {
      UserView(id: uid, style: .compact)
      if let action = self.action {
        Spacer()
        Button(action: action) {
          HStack(spacing: 2) {
            Text("    ")
            Image(systemName: "chevron.right")
          } .font(.callout)
            .foregroundColor(.secondary)
        } .buttonStyle(.plain)
      }
    }
  }
}
