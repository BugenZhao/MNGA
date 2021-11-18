//
//  ToastModifier.swift
//  NGA
//
//  Created by Bugen Zhao on 7/15/21.
//

import Foundation
import SwiftUI
import AlertToast

struct MainToastModifier: ViewModifier {
  @StateObject var notis = NotificationModel.shared
  @StateObject var hud = ToastModel.hud
  @StateObject var banner = ToastModel.banner

  var onTap: (() -> ())? {
    if case .notification(_) = hud.message {
      return { notis.showingSheet = true }
    }
    return nil
  }

  func body(content: Content) -> some View {
    content

      .toast(isPresenting: $hud.message.isNotNil(), duration: 3, tapToDismiss: onTap == nil) {
      (hud.message ?? .success("")).toastView(for: .hud)
    } onTap: { if let onTap = onTap { onTap() } }

      .toast(isPresenting: $banner.message.isNotNil(), duration: 3, tapToDismiss: onTap == nil) {
      (banner.message ?? .success("")).toastView(for: .banner(.pop))
    } onTap: { if let onTap = onTap { onTap() } }
  }
}

struct AlertToastModifier: ViewModifier {
  @StateObject var alert = ToastModel.editorAlert

  func body(content: Content) -> some View {
    content
      .toast(isPresenting: $alert.message.isNotNil(), duration: 3, tapToDismiss: true) {
      (alert.message ?? .success("")).toastView(for: .alert)
    }
  }
}
