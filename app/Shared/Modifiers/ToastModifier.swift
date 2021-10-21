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
  @StateObject var notis = NotificationModel.shared
  @StateObject var hud = ToastModel.hud

  func body(content: Content) -> some View {
    var onTap: (() -> ())?
    if case .notification(_) = hud.message {
      onTap = { notis.showingSheet = true }
    }

    return content
      .toast(isPresenting: $hud.message.isNotNil(), duration: 3, tapToDismiss: onTap == nil) {
      (hud.message ?? .success("")).toastView(for: .hud)
    } onTap: {
      if let onTap = onTap {
        onTap()
      }
    }
  }
}

struct AlertToastModifier: ViewModifier {
  @StateObject var alert = ToastModel.alert

  func body(content: Content) -> some View {
    content
      .toast(isPresenting: $alert.message.isNotNil(), duration: 3, tapToDismiss: true) {
      (alert.message ?? .success("")).toastView(for: .alert)
    }
  }
}
