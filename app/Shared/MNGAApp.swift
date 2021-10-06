//
// Created by Bugen Zhao on 7/2/21.
//

import Foundation
import SwiftUI

@main
struct MNGAApp: App {
  init() {
    logger.info("MNGA Init")
    logicInitialConfigure()
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
    }

    #if os(macOS)
      Settings {
        PreferencesInnerView()
      }
    #endif
  }
}
