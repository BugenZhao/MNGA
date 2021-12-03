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
    logger.info("open url: \(url)")
    #if os(iOS)
      if inApp ?? prefs.useInAppSafari, url.scheme?.starts(with: "http") == true {
        inAppURL = url
      } else {
        UIApplication.shared.open(url)
      }
    #else // ignore inApp option
      NSWorkspace.shared.open(url)
    #endif
  }
}
