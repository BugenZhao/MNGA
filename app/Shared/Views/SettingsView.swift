//
//  SettingsView.swift
//  SettingsView
//
//  Created by Bugen Zhao on 7/20/21.
//

import Foundation
import SwiftUI

struct SettingsView: View {
  @ViewBuilder
  var list: some View {
    List {
      Section(header: Text("Reading")) {
        NavigationLink(destination: BlockWordListView()) {
          Label("Block Words", systemImage: "eye.slash")
        }
      }
    } .listStyle(.insetGrouped)
  }

  var body: some View {
    NavigationView {
      list
        .navigationTitle("Settings")
    }
  }
}
