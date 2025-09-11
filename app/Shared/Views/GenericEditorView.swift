//
//  GenericEditorView.swift
//  GenericEditorView
//
//  Created by Bugen Zhao on 7/16/21.
//

import Foundation
import SwiftUI

private struct GenericEditorViewInner<T: TaskProtocol, M: GenericPostModel<T>>: View {
  enum DisplayMode: String, CaseIterable {
    case plain = "Plain"
    case preview = "Preview"
  }

  @Environment(\.presentationMode) var presentation

  @EnvironmentObject var postReply: M
  @EnvironmentObject var currentUser: CurrentUserModel

  @State var displayMode = DisplayMode.plain

  @State var subject = nil as Subject?
  @State var parsedContent = PostContent()

  @StateObject var presendAttachments = PresendAttachmentsModel()
  @StateObject var prefs = PreferencesStorage.shared

  var title: LocalizedStringKey {
    postReply.context?.task.actionTitle ?? "Editor"
  }

  var device: Device {
    prefs.requestOption.device
  }

  @ViewBuilder
  var picker: some View {
    Picker("Display Mode", selection: $displayMode.animation()) {
      ForEach(DisplayMode.allCases, id: \.rawValue) {
        Text(LocalizedStringKey($0.rawValue)).tag($0)
      }
    }.pickerStyle(SegmentedPickerStyle())
  }

  @ViewBuilder
  var previewInner: some View {
    if let subject {
      TopicSubjectView(topic: .with { $0.subject = subject }, showIndicators: false)
    }

    VStack(alignment: .leading, spacing: 10) {
      if postReply.context?.anonymous == true {
        UserView(user: .anonymousExample, style: .normal)
      } else if let user = currentUser.user {
        UserView(user: user, style: .normal)
      }

      PostContentView(content: parsedContent)

      HStack {
        Spacer()
        Image(systemName: device.icon)
          .frame(width: 10)
          .foregroundColor(.secondary)
          .font(.footnote)
      }
    }.padding(.vertical, 2)
      .fixedSize(horizontal: false, vertical: true)
  }

  @ViewBuilder
  var preview: some View {
    List {
      Section(header: Text("Preview")) {
        previewInner
      }
    }.onAppear { parseContent() }
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
      parsedContent = response?.content ?? .init()
    }
    if let subject = postReply.context?.subject {
      DispatchQueue.global(qos: .userInitiated).async {
        let response: SubjectParseResponse? = try? logicCall(.subjectParse(.with { $0.raw = subject }))
        self.subject = response?.subject
      }
    }
  }

  @ViewBuilder
  var sendButton: some View {
    Button(role: .confirm, action: { doSend() }) {
      if postReply.isSending {
        ProgressView()
      } else {
        Image(systemName: "paperplane.fill")
      }
    }
  }

  @ViewBuilder
  var previewButton: some View {
    Button(action: { withAnimation { displayMode = .preview } }) {
      Text("Preview")
    }
  }

  @ViewBuilder
  var cancelButton: some View {
    Button(action: { presentation.dismiss() }) {
      Text("Cancel")
    }
  }

  @ViewBuilder
  var discardButton: some View {
    Button(role: .destructive, action: { postReply.discardCurrentContext() }) {
      Image(systemName: "trash").foregroundColor(.red)
    }
  }

  #if os(iOS)
    var body: some View {
      inner
        .mayGroupedListStyle()
        .modifier(AlertToastModifier())
        .navigationTitleInline(key: title)
        .environmentObject(presendAttachments)
        .toolbar {
          ToolbarItem(placement: .confirmationAction) {
            switch displayMode {
            case .plain: previewButton
            case .preview: sendButton
            }
          }
          ToolbarItem(placement: .cancellationAction) { discardButton }
          ToolbarItem(placement: .bottomBar) { picker }
        }
    }

  #elseif os(macOS)
    var body: some View {
      if let context = postReply.context {
        VStack {
          HStack {
            ContentEditorView.build(context: $postReply.context ?? .dummy)
              .id(context.task)
            Divider()
            preview
              .onChange(of: context.subject) { _ in parseContent() }
              .onChange(of: context.content) { _ in parseContent() }
          }
          Divider()
          HStack {
            discardButton
            Spacer()
            cancelButton.keyboardShortcut(.cancelAction)
            sendButton.keyboardShortcut(.defaultAction)
          }
        }
      } else {
        ProgressView()
      }
    }
  #endif

  func doSend() {
    postReply.send()
  }
}

struct GenericEditorView<T: TaskProtocol, M: GenericPostModel<T>>: View {
  var body: some View {
    #if os(iOS)
      NavigationView {
        GenericEditorViewInner<T, M>()
      }
    #else
      GenericEditorViewInner<T, M>()
        .padding()
        .frame(width: 800, height: 600)
    #endif
  }
}

struct GenericPostEditorView_Previews: PreviewProvider {
  struct Preview: View {
    @StateObject var postReply = PostReplyModel()
    let defaultText: String?

    var body: some View {
      GenericEditorView<PostReplyTask, PostReplyModel>()
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
