//
//  ViewExtensions.swift
//  View+RedactedIf
//
//  Created by Bugen Zhao on 8/17/21.
//

import Foundation
import SwiftUI

public extension View {
  func `if`(_ cond: @autoclosure () -> Bool, content: (Self) -> some View) -> some View {
    Group {
      if cond() {
        content(self)
      } else {
        self
      }
    }
  }
}

public extension View {
  func redacted(if cond: @autoclosure () -> Bool, reason: RedactionReasons = .placeholder) -> some View {
    redacted(reason: cond() ? reason : [])
  }
}

struct OnDisappearOrInactiveModifier: ViewModifier {
  @Environment(\.scenePhase) var scenePhase

  let action: () -> Void

  func body(content: Content) -> some View {
    content
      .onDisappear(perform: action)
      .onChange(of: scenePhase) {
        // Swipe to home: active -> inactive -> background
        // Back to app: background -> inactive -> active
        // When in multitask mode, app can be inactive if it's not focused.
        // So we detect the switch of inactive and active, but not background.
        if $0 == .active, $1 == .inactive { action() }
      }
  }
}

public extension View {
  func onDisappearOrInactive(perform action: @escaping () -> Void) -> some View {
    modifier(OnDisappearOrInactiveModifier(action: action))
  }
}
