//
// Created by Bugen Zhao on 7/2/21.
//

import Foundation
import SwiftUI

@main
struct iOSNGAApp: App {
  @StateObject var authStorage = AuthStorage.shared

  init() {
    logger.info("iOS init")
    initConf()
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .sheet(isPresented: $authStorage.isSigning) { LoginView() }
        .onAppear { if !authStorage.signedIn { authStorage.isSigning = true } }
    }
  }
}
