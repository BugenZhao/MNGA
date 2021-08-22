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
    if inApp ?? prefs.useInAppSafari {
      self.inAppURL = url
    } else {
      #if os(iOS)
        UIApplication.shared.open(url)
      #elseif os(macOS)
        NSWorkspace.shared.open(url)
      #endif
    }
  }
}
