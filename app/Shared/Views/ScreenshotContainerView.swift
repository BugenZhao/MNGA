//
//  ScreenshotContainerView.swift
//  MNGA
//
//  Created by Bugen Zhao on 2026/01/26.
//

import SwiftUI
import SwiftUIX

struct ScreenshotHeaderView: View {
  var body: some View {
    HStack(alignment: .center) {
      Spacer()
      Image("mnga_logo")
        .renderingMode(.template)
        .resizable()
        .scaledToFit()
        .frame(height: 36)
      Spacer()
    }
    .foregroundColor(.accentColor)
  }
}

struct ScreenshotContainerView<Content: View>: View {
  let colorScheme: ColorScheme
  @StateObject var prefs = PreferencesStorage.shared

  let content: Content

  init(colorScheme: ColorScheme, @ViewBuilder content: () -> Content) {
    self.colorScheme = colorScheme
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading) {
      ScreenshotHeaderView()

      Divider().height(20)

      content
    }
    .padding()
    .frame(width: Screen.main.bounds.size.width)
    .background(.secondarySystemGroupedBackground)
    .environment(\.colorScheme, colorScheme)
    .accentColor(prefs.themeColor.color)
  }
}
