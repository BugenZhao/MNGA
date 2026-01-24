//
//  TopicJumpSelectorView.swift
//  MNGA
//
//  Created by Bugen Zhao on 2021/10/22.
//

import Foundation
import SwiftUI
import SwiftUIX

private struct NumberField: View {
  let title: LocalizedStringKey
  @Binding var text: String
  @State var selection: TextSelection?
  @FocusState var isFocused: Bool

  var body: some View {
    TextField(title, text: $text, selection: $selection)
      .focused($isFocused)
      .onChange(of: isFocused) { if $1 { selection = TextSelection(range: text.startIndex ..< text.endIndex) } }
      .keyboardType(.numberPad)
      .multilineTextAlignment(.trailing)
  }
}

struct TopicJumpSelectorView: View {
  @Environment(\.presentationMode) var presentation

  enum Mode: String, CaseIterable {
    case floor = "Floor"
    case page = "Page"
  }

  let maxFloor: Int
  @Binding var mode: Mode
  @Binding var floorToJump: Int?
  @Binding var pageToJump: Int?

  @State var selectedFloor: Int // the only source of truth

  init(maxFloor: Int, mode: Binding<Mode>, initialFloor: Int, floorToJump: Binding<Int?>, pageToJump: Binding<Int?>) {
    self.maxFloor = maxFloor
    _mode = mode
    _floorToJump = floorToJump
    _pageToJump = pageToJump
    _selectedFloor = .init(initialValue: min(initialFloor, maxFloor))
  }

  var maxPage: Int { (maxFloor + Constants.postPerPage) / Constants.postPerPage }

  var selectedFloorText: Binding<String> {
    .init(
      get: { String(selectedFloor) },
      set: { newValue in
        guard let number = Int(newValue) else { return }
        selectedFloor = min(max(number, 0), maxFloor)
      },
    )
  }

  var selectedPage: Binding<Int> {
    .init(
      get: { (selectedFloor + Constants.postPerPage) / Constants.postPerPage },
      set: { selectedFloor = ($0 - 1) * Constants.postPerPage },
    )
  }

  var selectedPageText: Binding<String> {
    .init(
      get: { String(selectedPage.wrappedValue) },
      set: { newValue in
        guard let number = Int(newValue) else { return }
        selectedPage.wrappedValue = min(max(number, 1), maxPage)
      },
    )
  }

  @ViewBuilder
  var jumpButton: some View {
    Button(role: .maybeConfirm, action: { commit() }) { Image(systemName: "arrowshape.bounce.right") }
  }

  @ViewBuilder
  var modeSelector: some View {
    Picker("Mode", selection: $mode) {
      ForEach(Mode.allCases, id: \.rawValue) {
        Text(LocalizedStringKey($0.rawValue)).tag($0)
      }
    }
    .pickerStyle(.segmented)
  }

  @ViewBuilder
  var floorInputField: some View {
    NumberField(title: "Floor number", text: selectedFloorText)
  }

  @ViewBuilder
  var pageInputField: some View {
    NumberField(title: "Page number", text: selectedPageText)
  }

  @ViewBuilder
  var floorSlider: some View {
    // Slider doesn't allow max == min
    if maxFloor > 0 {
      VStack(spacing: 8) {
        HStack {
          Text("0")
            .font(.caption)
            .foregroundColor(.secondary)
          Spacer()
          Text("\(maxFloor)")
            .font(.caption)
            .foregroundColor(.secondary)
        }

        Slider(
          value: .convert($selectedFloor),
          in: 0 ... Double(maxFloor),
          step: 1,
        )
      }
    }
  }

  @ViewBuilder
  var pageSlider: some View {
    // Slider doesn't allow max == min
    if maxPage > 1 {
      VStack(spacing: 8) {
        HStack {
          Text("1")
            .font(.caption)
            .foregroundColor(.secondary)
          Spacer()
          Text("\(maxPage)")
            .font(.caption)
            .foregroundColor(.secondary)
        }

        Slider(
          value: .convert(selectedPage),
          in: 1 ... Double(maxPage),
          step: 1,
        )
      }
    }
  }

  @ViewBuilder
  var main: some View {
    VStack(spacing: 0) {
      modeSelector
        .padding()

      List {
        switch mode {
        case .floor:
          Section(header: Text("Jump to...")) {
            HStack {
              Text("Floor")
              floorInputField
            }
            floorSlider
          }

        case .page:
          Section(header: Text("Jump to...")) {
            HStack {
              Text("Page")
              pageInputField
            }
            pageSlider
          }
        }
      }
      .listStyle(.insetGrouped)
    }
  }

  func commit() {
    floorToJump = selectedFloor
    pageToJump = selectedPage.wrappedValue
    presentation.dismiss()
  }

  var body: some View {
    NavigationView {
      main
        .mayInsetGroupedListStyle()
        .toolbar { ToolbarItem(placement: .primaryAction) { jumpButton } }
    }
  }
}
