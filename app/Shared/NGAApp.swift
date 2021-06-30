//
//  NGAApp.swift
//  Shared
//
//  Created by Bugen Zhao on 6/27/21.
//

import SwiftUI

@main
struct NGAApp: App {
  init() {
    print("swift: init")
    let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}
