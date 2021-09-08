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

  var title: LocalizedStringKey {
    postReply.context?.task.action.title ?? "Editor"
  }

  @ViewBuilder
  var picker: some View {
    Picker("Display Mode", selection: $displayMode.animation()) {
      ForEach(DisplayMode.allCases, id: \.rawValue) {
        Text(LocalizedStringKey($0.rawValue)).tag($0)
      }
    } .pickerStyle(.segmented)
  }

  @ViewBuilder
  var preview: some View {
    List {
      Section(header: Text("Preview")) {
        PostContentView(spans: spans)
      }
    } .listStyle(GroupedListStyle())
      .onAppear { parseContent() }
      .environment(\.inRealPost, false)
  }

  var subjectBinding: Binding<String?> {
    ($postReply.context ?? .dummy).subject
  }

  var contentBinding: Binding<String> {
    ($postReply.context ?? .dummy).content ?? ""
  }

  @ViewBuilder
  var inner: some View {
    if let context = postReply.context {
      switch displayMode {
      case .plain:
        ContentEditorView.build(subject: subjectBinding, content: contentBinding)
          .id(context.task)
      case .preview:
        preview
      }
    } else {
      ProgressView()
    }
  }

  func parseContent() {
    DispatchQueue.global(qos: .userInitiated).async {
      let content = (postReply.context?.content ?? "").replacingOccurrences(of: "\n", with: "<br/>")
      let response: ContentParseResponse? = try? logicCall(.contentParse(.with { $0.raw = content }))
      DispatchQueue.main.async {
        self.spans = response?.content.spans ?? []
      }
    }
  }

  var body: some View {
    NavigationView {
      inner
        .modifier(AlertToastModifier())
        .navigationBarTitle(title, displayMode: .inline)
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
          Button(action: { self.postReply.discardCurrentContext() }) {
            Text("Discard").foregroundColor(.red)
          }
        }
        ToolbarItem(placement: .bottomBar) {
          picker
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
