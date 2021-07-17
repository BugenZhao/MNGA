//
//  PostEditorView.swift
//  PostEditorView
//
//  Created by Bugen Zhao on 7/16/21.
//

import Foundation
import SwiftUI

struct PostEditorView: View {
  enum DisplayMode: String, CaseIterable {
    case plain = "Plain"
    case preview = "Preview"
  }

  @EnvironmentObject var postReply: PostReplyModel
  @State var displayMode = DisplayMode.plain
  @State var spans = [Span]()

  @ViewBuilder
  var picker: some View {
    Picker("Display Mode", selection: $displayMode.animation()) {
      ForEach(DisplayMode.allCases, id: \.rawValue) {
        Text(LocalizedStringKey($0.rawValue)).tag($0)
      }
    } .pickerStyle(.segmented)
  }

  @ViewBuilder
  var loading: some View {
    Spacer()
    HStack {
      Spacer()
      ProgressView()
      Spacer()
    }
    Spacer()
  }

  @ViewBuilder
  var inner: some View {
    VStack(alignment: .leading) {
      picker

      if postReply.context?.content == nil {
        loading
      } else {
        switch displayMode {
        case .plain:
          PostContentEditorView(content: postReply.contentBinding)
        case .preview:
          ScrollView {
            PostContentView(spans: spans)
              .frame(maxWidth: .infinity, alignment: .topLeading)
          } .onAppear { parseContent() }
        }
      }
    } .padding([.horizontal, .top])
  }

  func parseContent() {
    DispatchQueue.global(qos: .userInitiated).async {
      let response: ContentParseResponse? = try? logicCall(.contentParse(.with { $0.raw = postReply.context?.content ?? "" }))
      DispatchQueue.main.async {
        self.spans = response?.content.spans ?? []
      }
    }
  }

  var body: some View {
    NavigationView {
      inner
        .modifier(AlertToastModifier())
        .navigationBarTitle(postReply.context?.task.action.title ?? "Editor", displayMode: .inline)
        .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button(action: { doSend() }) {
            if postReply.isSending {
              ProgressView()
            } else {
              Text("Send")
            }
          }
        }
        ToolbarItem(placement: .cancellationAction) {
          Button(action: { self.postReply.forceRefreshCurrentContext() }) {
            Image(systemName: "arrow.clockwise")
          }
        }
      }
    }
  }

  func doSend() {
    self.postReply.send()
  }
}


struct PostEditorView_Previews: PreviewProvider {
  struct Preview: View {
    @StateObject var postReply = PostReplyModel()
    let defaultText: String?

    var body: some View {
      PostEditorView()
        .environmentObject(postReply)
        .onAppear {
        postReply.showEditor = true
        postReply.context = .init(task: .init(action: .init(), pageToReload: nil), content: defaultText) // dummy
      }
    }
  }

  static var previews: some View {
    Preview(defaultText: "Test\nTest\nTest\nTest\nTest\nTest\nTest\nTest\nTest\nTest\nTest\nTest\nTest\nTest\nTest\nTest\nTest\nTest\nTest\nTest\nTest\nTest\nTest\nTest\nTest\nTest\nTest\nTest\nTest\nTest\nTest\nTest\nTest\nTest\nTest\nTest\nTest\nTest\nTest\nTest\nTest\nTest\nTest\nTest\nTest\nTest\nTest\nTest\n")
    Preview(defaultText: nil)
  }
}
