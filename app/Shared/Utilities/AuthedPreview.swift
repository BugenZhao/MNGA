//
//  AuthedPreview.swift
//  NGA
//
//  Created by Bugen Zhao on 7/1/21.
//

import Foundation
import SwiftUI

struct AuthedPreview<Content: View>: View {
  #if DEBUG
    @StateObject var authStorage = AuthStorage(defaultAuthInfo: AUTH_INFO_DEBUG)
  #else
    @StateObject var authStorage = AuthStorage()
  #endif

  let build: () -> Content

  var body: some View {
    ContentView(testBody: build().eraseToAnyView())
      .environmentObject(authStorage)
  }
}
