//
//  ToastModel.swift
//  NGA
//
//  Created by Bugen Zhao on 7/14/21.
//

import AlertToast
import Combine
import Foundation
import SwiftUI

class ToastModel: ObservableObject {
  static let hud = ToastModel()
  static let banner = ToastModel()
  static let alert = ToastModel()
  static let editorAlert = ToastModel()

  enum Message {
    case success(String)
    case error(String)
    case notification(Int)
    case userSwitch(String)
    case clockIn(String)
    case openURL(URL)
    case autoRefreshed
  }

  @Published var message: Message? = nil

  private var cancellables = Set<AnyCancellable>()

  private init() {
    $message
      .removeDuplicates()
      .filter { $0 != nil }
      .sink { message in
        #if os(iOS)
          switch message! {
          case .error:
            HapticUtils.play(type: .error)
          case .notification:
            HapticUtils.play(type: .warning)
          default:
            HapticUtils.play(type: .success)
          }
        #endif
      }.store(in: &cancellables)
  }

  static func showAuto(_ message: Message?) {
    switch message {
    case .success, .error:
      ToastModel.banner.message = message
    case .notification, .userSwitch, .clockIn, .autoRefreshed, .openURL:
      ToastModel.hud.message = message
    // case .openURL:
    //   ToastModel.alert.message = message
    case .none:
      break
    }
  }
}

extension ToastModel.Message: Equatable {}
extension ToastModel.Message {
  func toastView(for displayMode: AlertToast.DisplayMode) -> AlertToast {
    switch self {
    case let .success(msg):
      AlertToast(displayMode: displayMode, type: .complete(.green), title: "Success".localized, subTitle: msg, style: .style(backgroundColor: .green.opacity(0.07)))
    case let .error(msg):
      AlertToast(displayMode: displayMode, type: .error(.red), title: "Error".localized, subTitle: msg.errorLocalized, style: .style(backgroundColor: .red.opacity(0.07)))
    case let .notification(newCount):
      AlertToast(displayMode: displayMode, type: .systemImage("bell.badge", .accentColor), title: "Notifications".localized, subTitle: String(format: "%lld new unread notifications".localized, newCount))
    case let .userSwitch(user):
      AlertToast(displayMode: displayMode, type: .systemImage("person.crop.circle.badge.checkmark", .accentColor), title: "Account Switched".localized, subTitle: user)
    case let .clockIn(msg):
      AlertToast(displayMode: displayMode, type: .systemImage("lanyardcard", .accentColor), title: "Clocked in Successfully".localized, subTitle: msg)
    case let .openURL(url):
      AlertToast(displayMode: displayMode, type: .complete(.accentColor), title: "Navigated to Link".localized, subTitle: url.absoluteString)
    case .autoRefreshed:
      AlertToast(displayMode: displayMode, type: .systemImage("checkmark.arrow.trianglehead.clockwise", .accentColor), title: "Auto Refreshed".localized, subTitle: nil)
    }
  }
}
