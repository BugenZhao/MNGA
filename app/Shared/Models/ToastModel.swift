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
  static let alert = ToastModel()

  enum Message {
    case success(String)
    case error(String)
    case notification(Int)
  }

  @Published var message: Message? = nil {
    willSet {
      if newValue != message, let newMessage = newValue {
        #if os(iOS)
          switch newMessage {
          case .success(_):
            HapticUtils.play(type: .success)
          case .error(_):
            HapticUtils.play(type: .error)
          case .notification(_):
            break
          }
        #endif
      }
    }
  }

  private init() { }
}

extension ToastModel.Message: Equatable { }
extension ToastModel.Message {
  func toast(for displayMode: AlertToast.DisplayMode) -> AlertToast {
    switch self {
    case .success(let msg):
      return AlertToast(displayMode: displayMode, type: .complete(.green), title: NSLocalizedString("Success", comment: ""), subTitle: msg)
    case .error(let msg):
      return AlertToast(displayMode: displayMode, type: .error(.red), title: NSLocalizedString("Error", comment: ""), subTitle: msg)
    case .notification(let newCount):
      return AlertToast(displayMode: displayMode, type: .systemImage("bell.badge", .accentColor), title: NSLocalizedString("Notifications", comment: ""), subTitle: String.localizedStringWithFormat(NSLocalizedString("%lld new unread notifications", comment: ""), newCount))
    }
  }
}
