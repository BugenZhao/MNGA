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
  @StateObject var activity = ActivityModel()

  func openGitHub() {
    let url = URL(string: "https://github.com/BugenZhao/MNGA")!
    OpenURLModel.shared.open(url: url, inApp: false)
  }

  func mail() {
    let url = URL(string: "mailto:mnga.feedback@bugenzhao.com")!
    OpenURLModel.shared.open(url: url, inApp: false)
  }

  func doShare() {
    self.activity.put(URL(string: Constants.URL.testFlight))
  }

  var version: String {
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String

    return "\(version ?? "??") (\(build ?? "?"))"
  }

  @ViewBuilder
  var header: some View {
    VStack {
      Button(action: { doShare() }) {
        Image("RoundedIcon")
          .resizable()
          .scaledToFit()
          .height(200)
      }
      Text("MNGA")
        .font(.largeTitle.bold())
        +
        Text("  \(version)")
        .font(.footnote)
      Text("Make NGA Great Again")

      HStack {
        Button(action: { openGitHub() }) {
          Image("github")
            .renderingMode(.template)
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
      } .foregroundColor(.accentColor)
    }
  }

  @ViewBuilder
  var description: some View {
    Text("\t") +
      Text("MNGA Description")
  }

  @ViewBuilder
  var footer: some View {
    Text("@bugen")
      .font(.callout)
      .foregroundColor(.secondary)
  }

  @ViewBuilder
  var shareButton: some View {
    Button(action: { doShare() }) {
      Label("Share", systemImage: "square.and.arrow.up")
    }
  }

  var body: some View {
    GeometryReader { geometry in
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
    }
      .navigationTitle("About & Feedback")
      .navigationBarTitleDisplayMode(.inline)
      .toolbarWithFix {
        ToolbarItem(placement: .status) { footer }
        ToolbarItem(placement: .navigationBarTrailing) { shareButton }
      }
      .sheet(isPresented: $activity.activityItems.isNotNil(), content: {
        AppActivityView(activityItems: activity.activityItems ?? [])
      })
  }
}


struct AboutView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      AboutView()
    }
  }
}
