//
//  DismissableStubView.swift
//  MNGA (macOS)
//
//  Created by Bugen Zhao on 2021/10/6.
//

import Foundation
import SwiftUI

struct DismissableStubView: View {
  @Environment(\.presentationMode) var presentation

  var body: some View {
    VStack {
      Text("Stub View")
      Button(action: { presentation.dismiss() }) {
        Text("Done")
      } .keyboardShortcut(.defaultAction)
    } .frame(width: 400, height: 300)
  }
}
