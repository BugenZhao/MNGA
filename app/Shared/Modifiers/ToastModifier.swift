//
//  ToastModifier.swift
//  NGA
//
//  Created by Bugen Zhao on 7/15/21.
//

import Foundation
import SwiftUI
import AlertToast

struct ToastModifier: ViewModifier {
  @StateObject var toast = ToastModel.shared

  func body(content: Content) -> some View {
    content
      .toast(isPresenting: $toast.message.isNotNil(), duration: 3, tapToDismiss: true) {
      switch toast.message ?? .success("") {
      case .success(let msg):
        return AlertToast(displayMode: .hud, type: .complete(.green), title: NSLocalizedString("Success", comment: ""), subTitle: msg)
      case .error(let msg):
        return AlertToast(displayMode: .hud, type: .error(.red), title: NSLocalizedString("Error", comment: ""), subTitle: msg)
      }
    }
  }
}
