//
// Created by Bugen Zhao on 7/2/21.
//

import Foundation
import SwiftUI
import SwiftUIX

@main
struct MNGAApp: App {
  @StateObject var prefs = PreferencesStorage()

  init() {
    logger.info("MNGA Init")
    logicInitialConfigure()
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .onChange(of: prefs.themeColor) { _ in setupColor() }
        .onAppear { setupColor() }
    }

    #if os(macOS)
      Settings {
        PreferencesInnerView()
      }
    #endif
  }

  func setupColor() {
    guard
      let window = AppKitOrUIKitApplication.shared.windows.filter(\.isKeyWindow).first
    else { return }

    window.tintColor = prefs.themeColor.color?.toUIColor()
  }
}
