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
    case userSwitch(String)
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
        case .success(_), .userSwitch(_):
          HapticUtils.play(type: .success)
        case .error(_):
          HapticUtils.play(type: .error)
        case .notification(_):
          HapticUtils.play(type: .warning)
        }
      #endif
    } .store(in: &cancellables)
  }
}

extension ToastModel.Message: Equatable { }
extension ToastModel.Message {
  func toastView(for displayMode: AlertToast.DisplayMode) -> AlertToast {
    switch self {
    case .success(let msg):
      return AlertToast(displayMode: displayMode, type: .complete(.green), title: NSLocalizedString("Success", comment: ""), subTitle: msg)
    case .error(let msg):
      return AlertToast(displayMode: displayMode, type: .error(.red), title: NSLocalizedString("Error", comment: ""), subTitle: msg)
    case .notification(let newCount):
      return AlertToast(displayMode: displayMode, type: .systemImage("bell.badge", .accentColor), title: NSLocalizedString("Notifications", comment: ""), subTitle: String.localizedStringWithFormat(NSLocalizedString("%lld new unread notifications", comment: ""), newCount))
    case .userSwitch(let user):
      return AlertToast(displayMode: displayMode, type: .systemImage("person.crop.circle.badge.checkmark", .accentColor), title: NSLocalizedString("User Switched", comment: ""), subTitle: user)
    }
  }
}
