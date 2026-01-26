//
//  ScreenshotContainerView.swift
//  MNGA
//
//  Created by Bugen Zhao on 2026/01/26.
//

import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import SwiftUIX

struct QRCodeView: View {
  let text: String
  @Environment(\.displayScale) private var displayScale

  private static let context = CIContext()

  private var qrCGImage: CGImage? {
    let data = Data(text.utf8)
    let filter = CIFilter.qrCodeGenerator()
    filter.setValue(data, forKey: "inputMessage")
    filter.setValue("L", forKey: "inputCorrectionLevel")
    guard let outputImage = filter.outputImage else { return nil }
    let colored = outputImage.applyingFilter("CIFalseColor", parameters: [
      "inputColor0": CIColor.black,
      "inputColor1": CIColor.clear,
    ])
    return Self.context.createCGImage(colored, from: colored.extent)
  }

  var body: some View {
    if let qrCGImage {
      Image(decorative: qrCGImage, scale: displayScale)
        .interpolation(.none)
        .renderingMode(.template)
        .resizable()
        .scaledToFit()
    }
  }
}

struct ScreenshotHeaderView: View {
  let mngaURL: URL?

  var body: some View {
    HStack(alignment: .center) {
      Image("mnga_logo")
        .renderingMode(.template)
        .resizable()
        .scaledToFit()
        .frame(height: 36)
      Spacer()
      if let mngaURL {
        QRCodeView(text: mngaURL.absoluteString)
          .frame(height: 40)
      }
    }
    .padding(.horizontal, 8)
    .foregroundColor(.accentColor)
  }
}

struct ScreenshotContainerView<Content: View>: View {
  let colorScheme: ColorScheme
  let mngaURL: URL?
  @StateObject var prefs = PreferencesStorage.shared

  let content: Content

  init(colorScheme: ColorScheme, mngaURL: URL?, @ViewBuilder content: () -> Content) {
    self.colorScheme = colorScheme
    self.mngaURL = mngaURL
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading) {
      ScreenshotHeaderView(mngaURL: mngaURL)
      Divider().height(16)
      content
    }
    .padding()
    .frame(width: Screen.main.bounds.size.width)
    .background(.secondarySystemGroupedBackground)
    .environment(\.colorScheme, colorScheme)
    .accentColor(prefs.themeColor.color)
  }
}
