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
  @Binding var value: Int
  let range: ClosedRange<Int>

  // Owned here so that clamping always changes state, and the field then shows the clamped text.
  @State private var text: String
  @State private var selection: TextSelection?
  @FocusState private var isFocused: Bool

  init(title: LocalizedStringKey, value: Binding<Int>, range: ClosedRange<Int>) {
    self.title = title
    _value = value
    self.range = range
    _text = .init(initialValue: String(value.wrappedValue))
  }

  var body: some View {
    TextField(title, text: $text, selection: $selection.fitting($text))
      .focused($isFocused)
      .onChange(of: isFocused) { if $1 { selection = TextSelection(range: text.startIndex ..< text.endIndex) } }
      .onChange(of: text) { commit($1) }
      .onChange(of: value) { if Int(text) != $1 { text = String($1) } }
      .keyboardType(.numberPad)
      .multilineTextAlignment(.trailing)
  }

  private func commit(_ newText: String) {
    // Leave the value alone while the field is empty, so that it can be cleared before typing.
    guard let number = Int(newText) else { return }
    let clamped = min(max(number, range.lowerBound), range.upperBound)
    value = clamped
    if newText != String(clamped) { text = String(clamped) }
  }
}

struct TopicJumpSelectorView: View {
  @Environment(\.presentationMode) var presentation

  enum Mode: String, CaseIterable {
    case floor = "Floor"
    case page = "Page"
  }

  let maxFloor: Int
  // A page load started now would be dropped by the data source.
  let isLoading: Bool
  @Binding var mode: Mode
  @Binding var floorToJump: Int?
  @Binding var pageToJump: Int?

  @State var selectedFloor: Int // the only source of truth

  // The page being read when the sheet opened. The page buttons go relative to it, not to the slider.
  private let currentPage: Int

  init(
    maxFloor: Int,
    isLoading: Bool,
    mode: Binding<Mode>,
    initialFloor: Int,
    floorToJump: Binding<Int?>,
    pageToJump: Binding<Int?>,
  ) {
    self.maxFloor = maxFloor
    self.isLoading = isLoading
    _mode = mode
    _floorToJump = floorToJump
    _pageToJump = pageToJump
    let floor = min(initialFloor, maxFloor)
    _selectedFloor = .init(initialValue: floor)
    currentPage = (floor + Constants.postPerPage) / Constants.postPerPage
  }

  var maxPage: Int { (maxFloor + Constants.postPerPage) / Constants.postPerPage }

  var selectedPage: Binding<Int> {
    .init(
      get: { (selectedFloor + Constants.postPerPage) / Constants.postPerPage },
      set: { selectedFloor = ($0 - 1) * Constants.postPerPage },
    )
  }

  @ViewBuilder
  var jumpButton: some View {
    Button(role: .maybeConfirm, action: { commit() }) { Image(systemName: "arrowshape.bounce.right") }
      .disabled(isLoading)
  }

  private func pageButton(_ title: LocalizedStringKey, to page: Int) -> some View {
    Button(action: {
      selectedPage.wrappedValue = page
      commit()
    }) {
      Text(title)
        .font(.subheadline)
        .fixedSize()
        .frame(maxWidth: .infinity)
    }
    .disabled(page == currentPage || !(1 ... maxPage).contains(page))
  }

  @ViewBuilder
  private var pageButtonList: some View {
    pageButton("First", to: 1)
    pageButton("Previous", to: currentPage - 1)
    pageButton("Next", to: currentPage + 1)
    pageButton("Last", to: maxPage)
  }

  @ViewBuilder
  var pageButtons: some View {
    if maxPage > 1 {
      // Stack them when the labels no longer fit in a row, as with accessibility text sizes.
      ViewThatFits(in: .horizontal) {
        HStack { pageButtonList }
        VStack { pageButtonList }
      }
      .buttonStyle(.bordered)
      .disabled(isLoading)
    }
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
    NumberField(title: "Floor number", value: $selectedFloor, range: 0 ... maxFloor)
  }

  @ViewBuilder
  var pageInputField: some View {
    NumberField(title: "Page number", value: selectedPage, range: 1 ... maxPage)
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
            pageButtons
          }

        case .page:
          Section(header: Text("Jump to...")) {
            HStack {
              Text("Page")
              pageInputField
            }
            pageSlider
            pageButtons
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
        .listStyle(.insetGrouped)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button(role: .cancel, action: { presentation.dismiss() }) { Image(systemName: "xmark") }
          }
          ToolbarItem(placement: .primaryAction) { jumpButton }
        }
    }
    // A drag that just misses the slider thumb, which is hard to hit at the leading edge, would close the sheet.
    .interactiveDismissDisabled()
  }
}
