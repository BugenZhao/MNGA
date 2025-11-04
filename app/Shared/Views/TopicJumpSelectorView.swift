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
    _selectedFloor = .init(initialValue: initialFloor)
  }

  var maxPage: Int { (maxFloor + Constants.postPerPage) / Constants.postPerPage }

  @Environment(\.presentationMode) var presentation

  @State var mode = Mode.floor
  @State var selectedFloor: Int
  @State var text = ""

  var selectedPage: Binding<Int> {
    .init(
      get: { (selectedFloor + Constants.postPerPage) / Constants.postPerPage },
      set: { selectedFloor = ($0 - 1) * Constants.postPerPage }
    )
  }

  @ViewBuilder
  var jumpButton: some View {
    Button(role: .confirm, action: { commit() }) { Image(systemName: "arrowshape.bounce.right") }
      .buttonStyle(.borderedProminent)
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
    NumberField(title: "Floor number", text: $text)
  }

  @ViewBuilder
  var pageInputField: some View {
    NumberField(title: "Page number", text: $text)
  }

  @ViewBuilder
  var floorSlider: some View {
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
        value: Binding(
          get: { Double(selectedFloor) },
          set: { value in
            withAnimation {
              selectedFloor = Int(value)
              text = String(selectedFloor)
            }
          }
        ),
        in: 0 ... Double(maxFloor),
        step: 1
      )
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
          }
        }
      }
      .listStyle(.insetGrouped)
    }
    .onChange(of: text) { parseText() }
    .onChange(of: mode) {
      updateTextForMode()
      parseText()
    }
    .onAppear {
      updateTextForMode()
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

  func updateTextForMode() {
    switch mode {
    case .floor:
      text = String(selectedFloor)
    case .page:
      text = String(selectedPage.wrappedValue)
    }
  }

  var body: some View {
    NavigationView {
      main
        .mayInsetGroupedListStyle()
        .toolbar { ToolbarItem(placement: .primaryAction) { jumpButton } }
        .scrollContentBackground(.hidden)
    }
  }
}

struct TopicJumpSelectorView_Previews: PreviewProvider {
  static var previews: some View {
    TopicJumpSelectorView(maxFloor: 799, floorToJump: .constant(nil))
    TopicJumpSelectorView(maxFloor: 1000, floorToJump: .constant(nil))
  }
}
