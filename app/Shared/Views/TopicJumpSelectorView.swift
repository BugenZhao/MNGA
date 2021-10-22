//
//  TopicJumpSelectorView.swift
//  MNGA
//
//  Created by Bugen Zhao on 2021/10/22.
//

import Foundation
import SwiftUI
import SwiftUIX

struct TopicJumpSelectorView: View {
  enum Mode: String, CaseIterable {
    case floor = "Floor"
    case page = "Page"
  }

  let maxFloor: Int
  let floorToJump: Binding<Int?>?
  let pageToJump: Binding<Int?>?

  init(maxFloor: Int, initialFloor: Int = 0, floorToJump: Binding<Int?>? = nil, pageToJump: Binding<Int?>? = nil) {
    self.maxFloor = maxFloor
    self.floorToJump = floorToJump
    self.pageToJump = pageToJump
    self._selectedFloor = .init(initialValue: initialFloor)
  }

  var maxPage: Int { (maxFloor + Constants.postPerPage) / Constants.postPerPage }

  @Environment(\.presentationMode) var presentation

  @State var mode = Mode.floor
  @State var selectedFloor: Int
  @State var text = ""

  var selectedPage: Binding<Int> {
      .init(get: { (selectedFloor + Constants.postPerPage) / Constants.postPerPage }, set: { selectedFloor = ($0 - 1) * Constants.postPerPage })
  }

  @ViewBuilder
  var jumpButton: some View {
    Button(action: { commit() }) { Text("Jump").bold() }
  }

  @ViewBuilder
  var main: some View {
    List {
      Section(header: Text("Jump to...")) {
        Group {
          Picker("Floor", selection: $selectedFloor) {
            ForEach(0..<maxFloor + 1) { i in
              Text("Floor \(i)").tag(i)
            }
          }
        } .pickerStyle(.wheel)

        HStack {
          Picker("", selection: $mode) {
            ForEach(Mode.allCases, id: \.rawValue) {
              Text(LocalizedStringKey($0.rawValue)).tag($0)
            }
          } .pickerStyle(MenuPickerStyle())

          TextField(NSLocalizedString("Type here...", comment: ""), text: $text)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.trailing)
        } .onChange(of: text) { _ in parseText() }
          .onChange(of: mode) { _ in parseText() }
      }

      Section {
        HStack {
          Button(action: { withAnimation { selectedFloor = 0 } }) {
            Text("First")
          } .frame(maxWidth: .infinity)
          Divider()
          Button(action: { withAnimation { selectedFloor = maxFloor } }) {
            Text("Last")
          } .frame(maxWidth: .infinity)
        } .buttonStyle(.plain)
          .foregroundColor(.accentColor)
      }
    }
  }

  func commit() {
    floorToJump?.wrappedValue = selectedFloor
    pageToJump?.wrappedValue = selectedPage.wrappedValue
    presentation.dismiss()
  }

  func parseText() {
    guard var number = Int(text) else { return }

    withAnimation {
      switch mode {
      case .floor:
        number = min(max(number, 0), maxFloor)
        selectedFloor = number
      case .page:
        number = min(max(number, 1), maxPage)
        selectedPage.wrappedValue = number
      }
    }
  }

  var body: some View {
    NavigationView {
      main
        .toolbarWithFix { ToolbarItem(placement: .primaryAction) { jumpButton } }
    }
  }
}

struct TopicJumpSelectorView_Previews: PreviewProvider {
  static var previews: some View {
    TopicJumpSelectorView(maxFloor: 210, floorToJump: .constant(nil))
  }
}
