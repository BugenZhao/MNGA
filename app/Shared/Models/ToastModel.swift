//
//  ToastModel.swift
//  NGA
//
//  Created by Bugen Zhao on 7/14/21.
//

import Foundation
import SwiftUI
import Combine
import AlertToast

class ToastModel: ObservableObject {
  static let hud = ToastModel()
  static let banner = ToastModel()
  static let editorAlert = ToastModel()

  enum Message {
    case success(String)
    case error(String)
    case notification(Int)
    case userSwitch(String)
    case clockIn(String)
    case openURL(URL)
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
        case .error(_):
          HapticUtils.play(type: .error)
        case .notification(_):
          HapticUtils.play(type: .warning)
        default:
          HapticUtils.play(type: .success)
        }
      #endif
    } .store(in: &cancellables)
  }

  static func showAuto(_ message: Message?) {
    switch message {
    case .success(_), .error(_), .openURL(_):
      ToastModel.banner.message = message
    case .notification(_), .userSwitch(_), .clockIn(_):
      ToastModel.hud.message = message
    case .none:
      break
    }
  }
}

extension ToastModel.Message: Equatable { }
extension ToastModel.Message {
  func toastView(for displayMode: AlertToast.DisplayMode) -> AlertToast {
    switch self {
    case .success(let msg):
      return AlertToast(displayMode: displayMode, type: .complete(.green), title: "Success".localized, subTitle: msg)
    case .error(let msg):
      return AlertToast(displayMode: displayMode, type: .error(.red), title: "Error".localized, subTitle: msg)
    case .notification(let newCount):
      return AlertToast(displayMode: displayMode, type: .systemImage("bell.badge", .accentColor), title: "Notifications".localized, subTitle: String.localizedStringWithFormat("%lld new unread notifications".localized, newCount))
    case .userSwitch(let user):
      return AlertToast(displayMode: displayMode, type: .systemImage("person.crop.circle.badge.checkmark", .accentColor), title: "Account Switched".localized, subTitle: user)
    case .clockIn(let msg):
      return AlertToast(displayMode: displayMode, type: .systemImage("lanyardcard", .accentColor), title: "Clocked in Successfully".localized, subTitle: msg)
    case .openURL(let url):
      return AlertToast(displayMode: displayMode, type: .systemImage("network", .accentColor), title: "Navigated to Link".localized, subTitle: url.absoluteString)
    }
  }
}
