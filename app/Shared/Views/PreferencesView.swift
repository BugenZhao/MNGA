//
//  PreferencesView.swift
//  NGA
//
//  Created by Bugen Zhao on 7/20/21.
//

import Foundation
import SwiftUI

struct PreferencesInnerView: View {
  @StateObject var pref = PreferencesStorage.shared

  @ViewBuilder
  var appearance: some View {
    Picker(selection: $pref.colorScheme, label: Label("Color Scheme", systemImage: "rays")) {
      ForEach(ColorSchemeMode.allCases, id: \.self) { mode in
        Text(mode.description)
      }
    }
    Picker(selection: $pref.themeColor, label: Label("Theme Color", systemImage: "circle")) {
      ForEach(ThemeColor.allCases, id: \.self) { color in
        Label(color.description) {
          Image(systemName: "circle.fill")
            .foregroundColor(color.color ?? Color("AccentColor"))
        } .tag(color)
      }
    }
  }

  @ViewBuilder
  var reading: some View {
//    Toggle(isOn: $pref.showTopicSubject) {
//      Label("Show Topic Subject", systemImage: "paragraphsign")
//    }
    Toggle(isOn: $pref.showSignature) {
      Label("Show Signature", systemImage: "signature")
    }
    Toggle(isOn: $pref.showAvatar) {
      Label("Show Avatar", systemImage: "person.circle")
    }
    Picker(selection: $pref.useRedact, label: Label("Collapsed Style", systemImage: "eye.slash")) {
      Text("Redact").tag(true)
      Text("Hidden").tag(false)
    }
    Toggle(isOn: $pref.usePaginatedDetails) {
      Label("Use Paginated Details", systemImage: "square.stack")
    }
    Toggle(isOn: $pref.useInAppSafari) {
      Label("Always Use In-App Safari", systemImage: "safari")
    }
    Picker(selection: $pref.defaultTopicListOrder, label: Label("Default Topic List Order", systemImage: "arrow.up.arrow.down")) {
      ForEach(TopicListRequest.Order.allCases, id: \.self) { order in
        Label(order.description, systemImage: order.icon).tag(order)
      }
    }
  }

  @ViewBuilder
  var connection: some View {
    Picker(selection: $pref.requestOption.baseURL, label: Label("Backend", systemImage: "server.rack")) {
      ForEach(URLs.hosts, id: \.self) { host in
        Text(host).tag(URLs.base(for: host)!.absoluteString)
      }
    }

    Picker(selection: $pref.requestOption.device, label: Label("Device Identity", systemImage: "ipad.and.iphone")) {
      ForEach(Device.allCases, id: \.self) { device in
        Label(device.description, systemImage: device.icon).tag(device)
      }
    }
  }

  @ViewBuilder
  var advanced: some View {
    Toggle(isOn: $pref.imageViewerEnableZoom) {
      Label("Enable Zoom for Image Viewer", systemImage: "arrow.up.left.and.arrow.down.right")
    }
  }

  #if os(macOS)
    var body: some View {
      TabView {
        Form { appearance }
          .tabItem { Label("Appearance", systemImage: "circle") }
          .tag("appearance")
        Form { reading }
          .tabItem { Label("Reading", systemImage: "eyeglasses") }
          .tag("reading")
        Form { connection }
          .tabItem { Label("Connection", systemImage: "network") }
          .tag("connection")
        Form { advanced }
          .tabItem { Label("Advanced", systemImage: "gearshape.2") }
          .tag("advanced")
      } .toggleStyle(SwitchToggleStyle(tint: .accentColor))
        .pickerStyle(InlinePickerStyle())
        .padding(20)
        .frame(width: 500)
    }
  #else
    var body: some View {
      Form {
        Section(header: Text("Appearance")) {
          appearance
        }

        Section(header: Text("Reading")) {
          NavigationLink(destination: BlockWordListView()) {
            Label("Block Words", systemImage: "hand.raised")
          }
          reading
        }

        Section(header: Text("Connection")) {
          connection
        }

        Section(header: Text("Advanced"), footer: Text("Options here are experimental or unstable.")) {
          NavigationLink(destination: CacheView()) {
            Label("Cache", systemImage: "internaldrive")
          }
          advanced
        }
      } .toggleStyle(SwitchToggleStyle(tint: .accentColor))
        .mayInsetGroupedListStyle()
        .navigationTitle("Preferences")
        .preferredColorScheme(pref.colorScheme.scheme) // workaround
    }
  #endif
}

struct PreferencesView: View {
  var body: some View {
    NavigationView {
      PreferencesInnerView()
    }
  }
}
