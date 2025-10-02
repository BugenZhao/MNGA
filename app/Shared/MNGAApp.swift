//
// Created by Bugen Zhao on 7/2/21.
//

import Foundation
import Inject
import SwiftUI
import SwiftUIX
import TipKit

@main
struct MNGAApp: App {
  @ObserveInjection var forceRedraw

  @StateObject var prefs = PreferencesStorage()
  @StateObject var networkMonitor = NetworkMonitor()

  init() {
    logger.info("MNGA Init")
    logicInitialConfigure()

    #if DEBUG
      if prefs.debugResetTips, (try? Tips.resetDatastore()) != nil {
        prefs.debugResetTips = false
        logger.info("reset tips datastore and the flag")
      }
    #endif
    try? Tips.configure()

    #if DEBUG
      if prefs.debugResetWhatsNew {
        MNGAWhatsNew.debugReset()
        prefs.debugResetWhatsNew = false
        logger.info("reset whatsnew and the flag")
      }
    #endif
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .onChange(of: prefs.themeColor) { setupColor() }
        .onAppear { setupColor() }
        .environment(\.whatsNew, MNGAWhatsNew.environment)
      // .enableInjection()
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
      window.tintColor = prefs.themeColor.color.toUIColor()
    #endif
  }
}
