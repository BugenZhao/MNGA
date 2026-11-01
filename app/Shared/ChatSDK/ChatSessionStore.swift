//
//  ChatSessionStore.swift
//  MNGA
//

import Foundation

@MainActor
final class ChatSessionStore: ObservableObject {
  @Published private(set) var session: ChatSession?

  private var scopeID: String?

  @discardableResult
  func prepare(
    scopeID: String,
    context: ChatContext,
    toolRegistry: ChatToolRegistry = .empty,
    clientFactory: @escaping ChatSession.ClientFactory,
  ) -> ChatSession {
    if self.scopeID == scopeID, let session {
      if !session.messages.isEmpty || session.isStreaming || session.context.id == context.id {
        return session
      }
    }

    session?.cancel()
    let session = ChatSession(
      context: context,
      toolRegistry: toolRegistry,
      clientFactory: clientFactory,
    )
    self.scopeID = scopeID
    self.session = session
    return session
  }

  func clearIfScopeChanged(to scopeID: String) {
    guard let currentScopeID = self.scopeID, currentScopeID != scopeID else { return }
    clear()
  }

  func clear() {
    session?.cancel()
    session = nil
    scopeID = nil
  }
}
