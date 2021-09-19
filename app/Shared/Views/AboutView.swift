//
//  AboutView.swift
//  AboutView
//
//  Created by Bugen Zhao on 2021/9/19.
//

import Foundation
import SwiftUI
import SwiftUIX

struct AboutView: View {
  func openGitHub() {
    let url = URL(string: "https://github.com/BugenZhao/MNGA")!
    OpenURLModel.shared.open(url: url, inApp: false)
  }

  func mail() {
    let url = URL(string: "mailto:mnga.feedback@bugenzhao.com")!
    OpenURLModel.shared.open(url: url, inApp: false)
  }

  var version: String {
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String

    return "\(version ?? "??") (\(build ?? "?"))"
  }

  @ViewBuilder
  var header: some View {
    VStack {
      Image("RoundedIcon")
        .resizable()
        .scaledToFit()
        .height(200)
      Text("MNGA")
        .font(.largeTitle.bold())
        +
        Text("  \(version)")
        .font(.footnote)
      Text("Make NGA Great Again")

      HStack {
        Button(action: { openGitHub() }) {
          Image("github")
            .resizable()
            .scaledToFit()
            .width(30)
        }
        Button(action: { mail() }) {
          Image(systemName: "envelope.fill")
            .resizable()
            .scaledToFit()
            .width(30)
        }
      } .foregroundColor(.primary)
    }
  }

  @ViewBuilder
  var description: some View {
    Text("\t") +
      Text("MNGA Description")
  }

  var body: some View {
    GeometryReader { geometry in
      VStack {
        ScrollView {
          VStack(spacing: 40) {
            header
            description
          }
            .fixedSize(horizontal: false, vertical: true)
            .padding()
            .frame(width: geometry.size.width)
            .frame(minHeight: geometry.size.height)
        }
        Text("@bugen")
          .font(.callout)
          .foregroundColor(.secondary)
      }
    }
      .navigationTitle("About & Feedback")
      .navigationBarTitleDisplayMode(.inline)
  }
}


struct AboutView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      AboutView()
    }
  }
}
