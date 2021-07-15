//
//  ToastModel.swift
//  NGA
//
//  Created by Bugen Zhao on 7/14/21.
//

import Foundation
import SwiftUI
import Combine

class ToastModel: ObservableObject {
  static let shared = ToastModel()

  enum Message {
    case success(String)
    case error(String)
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
          }
        #endif
      }
    }
  }

  private init() { }
}

extension ToastModel.Message: Equatable { }
