//
//  Snapshot.swift
//  MNGA (macOS)
//
//  Created by Bugen Zhao on 2021/10/5.
//

import Foundation
import SwiftUI
import SwiftUIX
import AppKit

extension View {
  func snapshot() -> AppKitOrUIKitImage {
    return .init(named: "RoundedIcon")!
  }
}
