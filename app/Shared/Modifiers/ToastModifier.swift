//
//  ToastModifier.swift
//  NGA
//
//  Created by Bugen Zhao on 7/15/21.
//

import Foundation
import SwiftUI
import AlertToast

struct HudToastModifier: ViewModifier {
  @StateObject var hud = ToastModel.hud


  func body(content: Content) -> some View {
    content
      .toast(isPresenting: $hud.message.isNotNil(), duration: 3, tapToDismiss: true) {
      (hud.message ?? .success("")).toast(for: .hud)
    }
  }
}

struct AlertToastModifier: ViewModifier {
  @StateObject var alert = ToastModel.alert

  func body(content: Content) -> some View {
    content
      .toast(isPresenting: $alert.message.isNotNil(), duration: 3, tapToDismiss: true) {
      (alert.message ?? .success("")).toast(for: .alert)
    }
  }
}
