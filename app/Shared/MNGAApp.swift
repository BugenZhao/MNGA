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
    #if os(iOS)
      guard let window = UIApplication.myKeyWindow else { return }
      window.tintColor = prefs.themeColor.color?.toUIColor()
    #endif
  }
}
