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
  case blue, gray, green, indigo, orange, pink, purple, red, teal, yellow
}

extension ThemeColor {
  var color: Color? {
    switch self {
    case .mnga: nil
    case .blue: .systemBlue
    case .gray: .systemGray
    case .green: .systemGreen
    case .indigo: .systemIndigo
    case .orange: .systemOrange
    case .pink: .systemPink
    case .purple: .systemPurple
    case .red: .systemRed
    case .teal: .systemTeal
    case .yellow: .systemYellow
    }
  }

  var description: LocalizedStringKey {
    switch self {
    case .mnga: "MNGA"
    case .blue: "Blue"
    case .gray: "Gray"
    case .green: "Green"
    case .indigo: "Indigo"
    case .orange: "Orange"
    case .pink: "Pink"
    case .purple: "Purple"
    case .red: "Red"
    case .teal: "Teal"
    case .yellow: "Yellow"
    }
  }
}
