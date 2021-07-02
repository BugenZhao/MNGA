//
// Created by Bugen Zhao on 7/2/21.
//

import Foundation
import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    return true
  }
}

@main
struct iOSNGAApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  @StateObject var authStorage = AuthStorage()

  init() {
    logger.info("iOS init")
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
