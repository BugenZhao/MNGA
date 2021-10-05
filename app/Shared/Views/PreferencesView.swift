//
//  PreferencesView.swift
//  NGA
//
//  Created by Bugen Zhao on 7/20/21.
//

import Foundation
import SwiftUI

struct PreferencesView: View {
  @StateObject var pref = PreferencesStorage.shared
  @StateObject var auth = AuthStorage.shared

  @ViewBuilder
  var list: some View {
    Form {
      Section(header: Text("Reading")) {
        NavigationLink(destination: BlockWordListView()) {
          Label("Block Words", systemImage: "hand.raised")
        }
        Toggle(isOn: $pref.showTopicSubject) {
          Label("Show Topic Subject", systemImage: "paragraphsign")
        }
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
      }

      Section(header: Text("Posting")) {
        Picker(selection: $auth.authInfo.inner.device, label: Label("Device Identity", systemImage: "ipad.and.iphone")) {
          ForEach(Device.allCases, id: \.hashIdentifiable) { device in
            Label(device.description, systemImage: device.icon).tag(device)
          }
        }
      }

      Section(header: Text("Advanced"), footer: Text("Options here are experimental or unstable.")) {
        Toggle(isOn: $pref.imageViewerEnableZoom) {
          Label("Enable Zoom for Image Viewer", systemImage: "arrow.up.left.and.arrow.down.right")
        }
        NavigationLink(destination: CacheView()) {
          Label("Cache", systemImage: "internaldrive")
        }
        Picker(selection: $pref.defaultTopicListOrder, label: Label("Default Topic List Order", systemImage: "arrow.up.arrow.down")) {
          ForEach(TopicListRequest.Order.allCases, id: \.self) { order in
            Label(order.description, systemImage: order.icon).tag(order)
          }
        }
      }

      Section(header: Text("Support")) {
        NavigationLink(destination: AboutView()) {
          Label("About & Feedback", systemImage: "hands.sparkles")
        }
      }
    } .toggleStyle(SwitchToggleStyle(tint: .accentColor))
      .mayInsetGroupedListStyle()
  }

  var body: some View {
    NavigationView {
      list
        .navigationTitle("Preferences")
    }
  }
}
