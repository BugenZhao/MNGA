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
  @StateObject var editorAlert = ToastModel.editorAlert

  let enableHud: Bool
  let enableBanner: Bool
  let enableAlert: Bool
  let enableEditorAlert: Bool

  init(enableHud: Bool, enableBanner: Bool, enableAlert: Bool, enableEditorAlert: Bool) {
    self.enableHud = enableHud
    self.enableBanner = enableBanner
    self.enableAlert = enableAlert
    self.enableEditorAlert = enableEditorAlert
  }

  static func main() -> Self {
    Self(enableHud: true, enableBanner: true, enableAlert: true, enableEditorAlert: false)
  }

  static func editorAlertOnly() -> Self {
    Self(enableHud: false, enableBanner: false, enableAlert: false, enableEditorAlert: true)
  }

  static func bannerOnly() -> Self {
    Self(enableHud: false, enableBanner: true, enableAlert: false, enableEditorAlert: false)
  }

  var hudOnTap: (() -> Void)? {
    if case .notification = hud.message {
      return { notis.showingSheet = true }
    }
    return nil
  }

  func body(content: Content) -> some View {
    content

      .if(enableHud) {
        $0.toast(isPresenting: $hud.message.isNotNil(), duration: 5, tapToDismiss: hudOnTap == nil, alert: {
          (hud.message ?? .success("")).toastView(for: .hud)
        }, onTap: hudOnTap)
      }
      .if(enableBanner) {
        $0.toast(isPresenting: $banner.message.isNotNil(), duration: 3, tapToDismiss: true, alert: {
          (banner.message ?? .success("")).toastView(for: .banner(.pop))
        })
      }
      .if(enableAlert) {
        $0.toast(isPresenting: $alert.message.isNotNil(), duration: 3, tapToDismiss: true, alert: {
          (alert.message ?? .success("")).toastView(for: .alert)
        })
      }
      .if(enableEditorAlert) {
        $0.toast(isPresenting: $editorAlert.message.isNotNil(), duration: 3, tapToDismiss: false) {
          (editorAlert.message ?? .success("")).toastView(for: .alert)
        }
      }
  }
}
