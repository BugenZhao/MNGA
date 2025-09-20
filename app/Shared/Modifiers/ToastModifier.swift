//
//  ToastModifier.swift
//  NGA
//
//  Created by Bugen Zhao on 7/15/21.
//

import AlertToast
import Foundation
import SwiftUI

struct MainToastModifier: ViewModifier {
  @StateObject var notis = NotificationModel.shared
  @StateObject var hud = ToastModel.hud
  @StateObject var banner = ToastModel.banner
  @StateObject var alert = ToastModel.alert

  var hudOnTap: (() -> Void)? {
    if case .notification = hud.message {
      return { notis.showingSheet = true }
    }
    return nil
  }

  func body(content: Content) -> some View {
    content

      .toast(isPresenting: $hud.message.isNotNil(), duration: 5, tapToDismiss: hudOnTap == nil, alert: {
        (hud.message ?? .success("")).toastView(for: .hud)
      }, onTap: hudOnTap)

      .toast(isPresenting: $banner.message.isNotNil(), duration: 3, tapToDismiss: true, alert: {
        (banner.message ?? .success("")).toastView(for: .banner(.pop))
      })

      .toast(isPresenting: $alert.message.isNotNil(), duration: 3, tapToDismiss: true, alert: {
        (alert.message ?? .success("")).toastView(for: .alert)
      })
  }
}

struct AlertToastModifier: ViewModifier {
  @StateObject var alert = ToastModel.editorAlert

  func body(content: Content) -> some View {
    content
      .toast(isPresenting: $alert.message.isNotNil(), duration: 3, tapToDismiss: false) {
        (alert.message ?? .success("")).toastView(for: .alert)
      }
  }
}
