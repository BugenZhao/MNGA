//
//  Appearance.swift
//  MNGA
//
//  Created by Bugen Zhao on 2021/10/20.
//

import Foundation
import SwiftUI
import SwiftUIX

enum ColorSchemeMode: Int, CaseIterable {
  case auto
  case light
  case dark
}

extension ColorSchemeMode {
  var scheme: ColorScheme? {
    switch self {
    case .auto: nil
    case .light: .light
    case .dark: .dark
    }
  }

  var description: LocalizedStringKey {
    switch self {
    case .auto: "Auto"
    case .light: "Light"
    case .dark: "Dark"
    }
  }
}

enum ThemeColor: Int, CaseIterable {
  case mnga
  case red
  case orange
  case yellow
  case green
  case mint
  case teal
  case cyan
  case blue
  case indigo
  case purple
  case pink
  case brown
  case gray
}

extension ThemeColor {
  var color: Color {
    switch self {
    // Note: Color("AccentColor") is always MNGA color, while `.accentColor` is the user's theme color.
    case .mnga: Color("AccentColor")
    case .red: .red
    case .orange: .orange
    case .yellow: .yellow
    case .green: .green
    case .mint: .mint
    case .teal: .teal
    case .cyan: .cyan
    case .blue: .blue
    case .indigo: .indigo
    case .purple: .purple
    case .pink: .pink
    case .brown: .brown
    case .gray: .gray
    }
  }

  var description: LocalizedStringKey {
    switch self {
    case .mnga: "MNGA"
    case .red: "Red"
    case .orange: "Orange"
    case .yellow: "Yellow"
    case .green: "Green"
    case .mint: "Mint"
    case .teal: "Teal"
    case .cyan: "Cyan"
    case .blue: "Blue"
    case .indigo: "Indigo"
    case .purple: "Purple"
    case .pink: "Pink"
    case .brown: "Brown"
    case .gray: "Gray"
    }
  }
}
