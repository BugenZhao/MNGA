//
//  TopicChatView.swift
//  MNGA
//

import SwiftUI

struct TopicChatView: View {
  @ObservedObject var session: ChatSession
  @ObservedObject private var configurationStore = ChatConfigurationStore.shared
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    Group {
      if configurationStore.isAIEnabled {
        ChatConversationView(session: session)
      } else {
        VStack(spacing: 16) {
          ContentUnavailableView(
            "AI Chat Is Not Verified",
            systemImage: "key.slash",
            description: Text("Configure the API and pass the connection test to start chatting."),
          )
          NavigationLink("Open AI Chat Settings") {
            AISettingsView()
          }
          .buttonStyle(.borderedProminent)
        }
      }
    }
    .navigationTitle("AI Chat")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        Button("Done") { dismiss() }
      }
    }
  }
}

private struct ChatConversationView: View {
  @ObservedObject var session: ChatSession
  @State private var draft = ""
  @State private var showingResetConfirmation = false
  @FocusState private var composerFocused: Bool

  private var coverageDescription: String? {
    guard let coverage = session.context.coverage else { return nil }
    var description = String(
      format: "AI context: %lld of %lld loaded posts (%lld total).".localized,
      coverage.includedItems,
      coverage.loadedItems,
      coverage.totalItems,
    )
    if coverage.isTruncated {
      description += " " + "Some loaded content was truncated to fit the AI context limit.".localized
    }
    return description
  }

  private func send() {
    let message = draft
    guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    draft = ""
    session.send(message)
  }

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(spacing: 14) {
          contextHeader

          ForEach(session.messages) { message in
            if message.role == .assistant {
              let activities = toolActivities(for: message.id)
              if !activities.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                  ForEach(activities) { activity in
                    ChatToolActivityView(activity: activity)
                  }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
              }
            }

            if shouldShowBubble(for: message) {
              ChatMessageBubble(message: message)
                .id(message.id)
            }
          }

          if let errorMessage = session.errorMessage {
            errorView(message: errorMessage)
          }

          Color.clear.frame(height: 1).id("chat-bottom")
        }
        .padding()
      }
      .scrollDismissesKeyboard(.interactively)
      .simultaneousGesture(
        TapGesture().onEnded { composerFocused = false },
      )
      .onChange(of: session.messages.last?.content) { _, _ in
        proxy.scrollTo("chat-bottom", anchor: .bottom)
      }
      .onChange(of: session.messages.count) { _, _ in
        withAnimation { proxy.scrollTo("chat-bottom", anchor: .bottom) }
      }
      .onChange(of: session.toolActivities) { _, _ in
        withAnimation { proxy.scrollTo("chat-bottom", anchor: .bottom) }
      }
    }
    .safeAreaInset(edge: .bottom) { composer }
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("New Chat", systemImage: "arrow.counterclockwise") {
          showingResetConfirmation = true
        }
        .disabled(session.messages.isEmpty)
      }
    }
    .confirmationDialog("Start a new chat?", isPresented: $showingResetConfirmation) {
      Button("New Chat", role: .destructive) { session.reset() }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("The current messages will be cleared. The topic context will remain available.")
    }
  }

  private func toolActivities(for messageID: UUID) -> [ChatToolActivity] {
    session.toolActivities.filter { $0.assistantMessageID == messageID }
  }

  private func shouldShowBubble(for message: ChatMessage) -> Bool {
    message.role == .user || !message.content.isEmpty || toolActivities(for: message.id).isEmpty
  }

  private var contextHeader: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label(session.context.title, systemImage: "text.bubble")
        .font(.headline)
      if let coverageDescription {
        Text(coverageDescription)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Text("AI responses may be inaccurate. Verify important information against the original topic.")
        .font(.caption)
        .foregroundStyle(.secondary)
      Text("AI can use read-only MNGA tools to search and load additional topics, forums, and users.")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
  }

  private func errorView(message: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("Chat Request Failed", systemImage: "exclamationmark.triangle")
        .font(.headline)
        .foregroundStyle(.red)
      Text(message)
        .font(.caption)
        .textSelection(.enabled)
      if session.canRetry {
        Button("Retry", action: session.retry)
          .buttonStyle(.bordered)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
  }

  private var composer: some View {
    HStack(alignment: .center, spacing: 10) {
      TextField("Ask about this topic", text: $draft, axis: .vertical)
        .focused($composerFocused)
        .lineLimit(1 ... 6)
        .textFieldStyle(.plain)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 18))
        .submitLabel(.send)
        .onSubmit(send)

      Button {
        if session.isStreaming {
          session.cancel()
        } else {
          send()
        }
      } label: {
        Image(systemName: session.isStreaming ? "stop.fill" : "arrow.up")
          .font(.headline)
          .foregroundStyle(.white)
          .frame(width: 38, height: 38)
          .background(Color.accentColor, in: Circle())
      }
      .disabled(!session.isStreaming && draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      .accessibilityLabel(session.isStreaming ? "Stop Generating" : "Send")
    }
    .padding(.horizontal)
    .padding(.top, 8)
    .padding(.bottom, 6)
    .background(.bar)
  }
}

private struct ChatToolActivityView: View {
  let activity: ChatToolActivity
  @State private var isExpanded = false

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Button {
        withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
      } label: {
        HStack(spacing: 8) {
          Image(systemName: toolIcon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(stateColor)
            .frame(width: 22, height: 22)
            .background(stateColor.opacity(0.12), in: Circle())
          Text(activity.displayName.localized)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.primary)
          if activity.reuseCount > 0 {
            Text("×\(activity.reuseCount + 1)")
              .font(.caption2.monospacedDigit().weight(.medium))
              .foregroundStyle(.secondary)
          }
          stateView
          Image(systemName: "chevron.right")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.tertiary)
            .rotationEffect(.degrees(isExpanded ? 90 : 0))
        }
        .padding(.leading, 8)
        .padding(.trailing, 10)
        .padding(.vertical, 7)
        .background(rowBackground, in: Capsule())
        .overlay {
          Capsule()
            .strokeBorder(stateColor.opacity(activity.state == .failed ? 0.22 : 0.08))
        }
        .fixedSize(horizontal: true, vertical: false)
        .contentShape(.rect)
      }
      .buttonStyle(.plain)

      if let failureDescription = activity.failureDescription, !isExpanded {
        Text(failureDescription)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(2)
          .padding(.horizontal, 10)
          .transition(.opacity)
      }

      if isExpanded {
        detailView
          .transition(.opacity.combined(with: .move(edge: .top)))
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var toolIcon: String {
    switch activity.toolName {
    case "search_topics", "search_forums":
      "magnifyingglass"
    case "get_user", "get_user_topics", "get_user_posts":
      "person.crop.circle"
    case "list_forum_topics", "get_hot_topics":
      "rectangle.stack"
    default:
      "text.page"
    }
  }

  private var stateColor: Color {
    switch activity.state {
    case .running: .accentColor
    case .succeeded: .green
    case .failed: .red
    case .cancelled: .secondary
    }
  }

  private var rowBackground: Color {
    switch activity.state {
    case .failed: .red.opacity(0.06)
    default: .secondary.opacity(0.07)
    }
  }

  @ViewBuilder
  private var stateView: some View {
    switch activity.state {
    case .running:
      ProgressView()
        .controlSize(.mini)
        .accessibilityLabel("Running")
    case .succeeded:
      Label(durationDescription ?? "Succeeded".localized, systemImage: "checkmark")
        .foregroundStyle(.secondary)
        .font(.caption2.monospacedDigit())
    case .failed:
      Label("Failed", systemImage: "exclamationmark.circle.fill")
        .foregroundStyle(.red)
        .font(.caption2)
    case .cancelled:
      Label("Cancelled", systemImage: "stop.circle")
        .foregroundStyle(.secondary)
        .font(.caption2)
    }
  }

  private var detailView: some View {
    VStack(alignment: .leading, spacing: 12) {
      jsonSection(title: "Parameters", value: activity.arguments)

      if let output = activity.output {
        jsonSection(title: "Result", value: output)
      } else {
        LabeledContent("Result") {
          Text(activity.state == .cancelled ? "Cancelled" : "Waiting for result...")
            .foregroundStyle(.secondary)
        }
      }

      HStack(spacing: 5) {
        Text(activity.toolName)
        Text("·")
        Text(activity.callID)
          .lineLimit(1)
          .truncationMode(.middle)
        if activity.reuseCount > 0 {
          Text("·")
          Text(String(format: "Reused %lld times".localized, activity.reuseCount))
        }
      }
      .font(.caption2.monospaced())
      .foregroundStyle(.tertiary)
      .textSelection(.enabled)
    }
    .font(.caption)
    .padding(12)
    .background(.secondary.opacity(0.055), in: RoundedRectangle(cornerRadius: 12))
    .overlay {
      RoundedRectangle(cornerRadius: 12)
        .strokeBorder(.secondary.opacity(0.08))
    }
  }

  private func jsonSection(title: LocalizedStringKey, value: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .foregroundStyle(.secondary)
      ScrollView(.horizontal) {
        Text(prettyJSON(value))
          .font(.caption2.monospaced())
          .textSelection(.enabled)
          .fixedSize(horizontal: true, vertical: false)
      }
      .contentMargins(10, for: .scrollContent)
      .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
  }

  private var durationDescription: String? {
    guard let duration = activity.duration else { return nil }
    return String(format: "%.2f s", duration)
  }

  private func prettyJSON(_ rawValue: String) -> String {
    let maximumCharacters = 12_000
    let value: String
    if let data = rawValue.data(using: .utf8),
       let object = try? JSONSerialization.jsonObject(with: data),
       let formattedData = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    {
      value = String(decoding: formattedData, as: UTF8.self)
    } else {
      value = rawValue
    }

    guard value.count > maximumCharacters else { return value }
    return String(value.prefix(maximumCharacters)) + "\n… " + "Result truncated for display.".localized
  }
}

private struct ChatMessageBubble: View {
  let message: ChatMessage

  private var isUser: Bool { message.role == .user }
  private var isWaitingForFirstContent: Bool {
    !isUser && message.content.isEmpty && message.deliveryState == .streaming
  }

  @ViewBuilder
  var body: some View {
    if isWaitingForFirstContent {
      ChatThinkingIndicator()
    } else {
      HStack {
        if isUser { Spacer(minLength: 44) }
        VStack(alignment: .leading, spacing: 6) {
          if isUser {
            Text(message.content)
              .textSelection(.enabled)
          } else {
            ChatMarkdownView(source: message.content)
          }

          if message.deliveryState == .cancelled {
            Label("Stopped", systemImage: "stop.circle")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
        }
        .frame(maxWidth: isUser ? nil : .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .foregroundStyle(isUser ? Color.white : Color.primary)
        .background(isUser ? Color.accentColor : Color.secondary.opacity(0.14), in: RoundedRectangle(cornerRadius: 18))
        .contextMenu {
          Button("Copy", systemImage: "doc.on.doc") {
            UIPasteboard.general.string = message.content
          }
        }
        if !isUser { Spacer(minLength: 44) }
      }
      .frame(maxWidth: .infinity)
    }
  }
}

private struct ChatThinkingIndicator: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    HStack(spacing: 8) {
      if reduceMotion {
        thinkingDots(activeIndex: 1)
      } else {
        PhaseAnimator([0, 1, 2]) { phase in
          thinkingDots(activeIndex: phase)
        } animation: { _ in
          .easeInOut(duration: 0.34)
        }
      }

      Text("Thinking")
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.leading, 6)
    .accessibilityElement(children: .combine)
  }

  private func thinkingDots(activeIndex: Int) -> some View {
    HStack(spacing: 3) {
      ForEach(0 ..< 3, id: \.self) { index in
        Circle()
          .fill(Color.accentColor.opacity(index == activeIndex ? 0.9 : 0.22))
          .frame(width: 5, height: 5)
          .scaleEffect(index == activeIndex ? 1.12 : 0.82)
      }
    }
    .accessibilityHidden(true)
  }
}
