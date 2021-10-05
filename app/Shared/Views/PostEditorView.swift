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

  @State var subject = nil as Subject?
  @State var parsedContent = PostContent()

  @StateObject var presendAttachments = PresendAttachmentsModel()

  var title: LocalizedStringKey {
    postReply.context?.task.action.title ?? "Editor"
  }
  
  var device: Device {
    AuthStorage.shared.authInfo.inner.device
  }

  @ViewBuilder
  var picker: some View {
    Picker("Display Mode", selection: $displayMode.animation()) {
      ForEach(DisplayMode.allCases, id: \.rawValue) {
        Text(LocalizedStringKey($0.rawValue)).tag($0)
      }
    } .pickerStyle(SegmentedPickerStyle())
  }

  @ViewBuilder
  var preview: some View {
    List {
      Section(header: Text("Preview")) {
        if let subject = self.subject {
          TopicSubjectView(topic: .with { $0.subject = subject }, showIndicators: false)
        }

        VStack(alignment: .leading) {
          PostContentView(content: parsedContent)
          HStack {
            Spacer()
            Image(systemName: device.icon)
              .frame(width: 10)
              .foregroundColor(.secondary)
              .font(.footnote)
          }
        }
      }
    } .mayGroupedListStyle()
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
        ContentEditorView.build(context: $postReply.context ?? .dummy)
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
      self.parsedContent = response?.content ?? .init()
    }
    if let subject = postReply.context?.subject {
      DispatchQueue.global(qos: .userInitiated).async {
        let response: SubjectParseResponse? = try? logicCall(.subjectParse(.with { $0.raw = subject }))
        self.subject = response?.subject
      }
    }
  }

  var body: some View {
    NavigationView {
      inner
        .modifier(AlertToastModifier())
        .navigationTitleInline(key: title)
        .environmentObject(presendAttachments)
        .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          switch displayMode {
          case .plain:
            Button(action: { withAnimation { displayMode = .preview } }) {
              Text("Preview")
            }
          case .preview:
            Button(action: { doSend() }) {
              if postReply.isSending {
                ProgressView()
              } else {
                Text("Send")
              }
            }
          }
        }
        ToolbarItem(placement: .cancellationAction) {
          Button(action: { self.postReply.discardCurrentContext() }) {
            Text("Discard").foregroundColor(.red)
          }
        }
        ToolbarItem(placement: .mayBottomBar) {
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
