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

  @ViewBuilder
  var list: some View {
    Form {
      Section(header: Text("Reading")) {
        NavigationLink(destination: BlockWordListView()) {
          Label("Block Words", systemImage: "hand.raised")
        }
        Toggle(isOn: $pref.showSignature) {
          Label("Show Signature", systemImage: "signature")
        }
        Toggle(isOn: $pref.showAvatar) {
          Label("Show Avatar", systemImage: "person.circle")
        }
        Picker(selection: $pref.useRedact) {
          Text("Redact").tag(true)
          Text("Hidden").tag(false)
        } label: {
          Label("Collapsed Style", systemImage: "eye.slash")
        }
      }
      
      Section(header: Text("Advanced")) {
        Toggle(isOn: $pref.useStackDetails) {
          Label("Use Stack for Details", systemImage: "square.stack")
        }
        NavigationLink(destination: CacheView()) {
          Label("Cache", systemImage: "internaldrive")
        }
      }
    } .toggleStyle(SwitchToggleStyle(tint: .accentColor))
      .listStyle(.insetGrouped)
  }

  var body: some View {
    NavigationView {
      list
        .navigationTitle("Preferences")
    }
  }
}
