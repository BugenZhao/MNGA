//
//  TextSelectionView.swift
//  MNGA
//
//  Created by Bugen Zhao on 2021/10/23.
//

import Foundation
import SwiftUI

class TextSelectionModel: ObservableObject {
  @Published var text: String? = nil
}

struct TextSelectionView: View {
  @EnvironmentObject var model: TextSelectionModel
  @Environment(\.presentationMode) var presentation

  var text: String { model.text ?? "" }

  @ViewBuilder
  var copyButton: some View {
    Button(action: { copyToPasteboard(string: text); presentation.dismiss() }) {
      Text("Copy All").bold()
    }
  }

  var body: some View {
    NavigationView {
      TextEditor(text: .constant(text))
        .introspect(.textEditor, on: .iOS(.v26)) { tv in
          tv.isEditable = false
          tv.selectAll(nil)
        }
        .padding(.horizontal)
        .toolbar { ToolbarItem(placement: .status) { copyButton } }
        .navigationTitleInline(key: "Text Selection")
    }
  }
}

struct TextSelectionView_Preview: PreviewProvider {
  struct Sheet: View {
    @StateObject var model = TextSelectionModel()

    var body: some View {
      TextSelectionView()
        .environmentObject(model)
        .onAppear { model.text = String(repeating: "Test String ", count: 1000) }
    }
  }

  static var previews: some View {
    Text("233")
      .sheet(isPresented: .constant(true)) { Sheet() }
  }
}
