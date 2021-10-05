//
// Created by Bugen Zhao on 7/2/21.
//

import Foundation
import SwiftUI

@main
struct MNGAApp: App {
  init() {
    logger.info("MNGA Init")
    initConf()
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}
