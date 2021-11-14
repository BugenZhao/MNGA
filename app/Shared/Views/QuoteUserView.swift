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
  let nameHint: String?
  let action: (() -> Void)?

  @Environment(\.enableShowReplyChain) var enableShowReplyChain

  var body: some View {
    HStack {
      UserView(id: uid, nameHint: nameHint, style: .compact)
      if let action = self.action, enableShowReplyChain {
        Spacer()
        Button(action: action) {
          HStack(spacing: 2) {
            Text("    ")
            Image(systemName: "chevron.right")
          } .font(.callout)
            .foregroundColor(.secondary)
        } .buttonStyle(PlainButtonStyle())
      }
    }
  }
}
