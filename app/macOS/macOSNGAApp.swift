//
// Created by Bugen Zhao on 7/2/21.
//

import SwiftUI

@main
struct macOSNGAApp: App {
  init() {
    logger.info("macOS init")
    initConf()
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .sheet(isPresented: .constant(authStorage.shouldLogin)) {
        LoginView()
      }
    }
  }
}
