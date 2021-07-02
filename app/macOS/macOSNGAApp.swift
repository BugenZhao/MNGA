//
// Created by Bugen Zhao on 7/2/21.
//

import SwiftUI

@main
struct macOSNGAApp: App {
  @StateObject var authStorage = AuthStorage()

  init() {
    logger.info("macOS init")
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .sheet(isPresented: .constant(authStorage.shouldLogin)) {
          LoginView()
        }.environmentObject(authStorage)
    }
  }
}
