//
//  NGAApp.swift
//  Shared
//
//  Created by Bugen Zhao on 6/27/21.
//

import SwiftUI

@main
struct NGAApp: App {
  @StateObject var authStorage = AuthStorage()

  init() {
    print("swift: init")
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .sheet(isPresented: .constant(authStorage.shouldLogin)) {
        LoginView()
          .environmentObject(authStorage)
      }
    }
  }
}
