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

  @Published var message: String? = nil {
    willSet {
      if newValue?.isEmpty == false && newValue != message {
        HapticUtils.play(type: .error)
      }
    }
  }

  private init() { }
}
