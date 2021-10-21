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
  case light, dark
}

extension ColorSchemeMode {
  var scheme: ColorScheme? {
    switch self {
    case .auto: return nil
    case .light: return .light
    case .dark: return .dark
    }
  }

  var description: LocalizedStringKey {
    switch self {
    case .auto: return "Auto"
    case .light: return "Light"
    case .dark: return "Dark"
    }
  }
}

enum ThemeColor: Int, CaseIterable {
  case mnga
  case blue, gray, green, indigo, orange, pink, purple, red, teal, yellow
}

extension ThemeColor {
  var color: Color? {
    switch self {
    case .mnga: return nil
    case .blue: return .systemBlue
    case .gray: return .systemGray
    case .green: return .systemGreen
    case .indigo: return .systemIndigo
    case .orange: return .systemOrange
    case .pink: return .systemPink
    case .purple: return .systemPurple
    case .red: return .systemRed
    case .teal: return .systemTeal
    case .yellow: return .systemYellow
    }
  }

  var description: LocalizedStringKey {
    switch self {
    case .mnga: return "MNGA"
    case .blue: return "Blue"
    case .gray: return "Gray"
    case .green: return "Green"
    case .indigo: return "Indigo"
    case .orange: return "Orange"
    case .pink: return "Pink"
    case .purple: return "Purple"
    case .red: return "Red"
    case .teal: return "Teal"
    case .yellow: return "Yellow"
    }
  }
}
