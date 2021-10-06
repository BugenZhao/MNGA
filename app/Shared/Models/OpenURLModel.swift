//
//  OpenURLModel.swift
//  OpenURLModel
//
//  Created by Bugen Zhao on 8/22/21.
//

import Foundation
import SwiftUIX

class OpenURLModel: ObservableObject {
  static let shared = OpenURLModel()

  @Published var inAppURL: URL?

  private let prefs = PreferencesStorage.shared

  func open(url: URL, inApp: Bool? = nil) {
    #if os(iOS)
      if inApp ?? prefs.useInAppSafari {
        self.inAppURL = url
      } else {
        UIApplication.shared.open(url)
      }
    #else // ignore inApp option
      NSWorkspace.shared.open(url)
    #endif
  }
}
