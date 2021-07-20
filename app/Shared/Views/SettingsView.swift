//
//  SettingsView.swift
//  SettingsView
//
//  Created by Bugen Zhao on 7/20/21.
//

import Foundation
import SwiftUI

struct SettingsView: View {
  @StateObject var pref = PreferencesStorage.shared

  @ViewBuilder
  var list: some View {
    List {
      Section(header: Text("Reading")) {
        NavigationLink(destination: BlockWordListView()) {
          Label("Block Words", systemImage: "eye.slash")
        }
        Toggle(isOn: $pref.showSignature) {
          Label("Show Signature", systemImage: "signature")
        }
      }
    } .toggleStyle(SwitchToggleStyle(tint: .accentColor))
      .listStyle(.insetGrouped)
  }

  var body: some View {
    NavigationView {
      list
        .navigationTitle("Settings")
    }
  }
}
