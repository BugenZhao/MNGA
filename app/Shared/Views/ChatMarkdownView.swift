//
//  ChatMarkdownView.swift
//  MNGA
//

import SwiftUI
import Textual

struct ChatMarkdownView: View {
  let source: String

  var body: some View {
    StructuredText(source, parser: ResilientMarkdownParser())
      .textual.structuredTextStyle(.gitHub)
      .textual.overflowMode(.scroll)
      .textual.textSelection(.enabled)
      .textual.imageAttachmentLoader(DisabledMarkdownImageLoader())
      .frame(maxWidth: .infinity, alignment: .leading)
      .transaction { $0.animation = nil }
  }
}

@MainActor
private struct ResilientMarkdownParser: MarkupParser {
  private let parser = AttributedStringMarkdownParser(baseURL: nil)

  func attributedString(for source: String) throws -> AttributedString {
    do {
      return try parser.attributedString(for: source)
    } catch {
      return AttributedString(source)
    }
  }
}

private struct DisabledMarkdownImageLoader: AttachmentLoader {
  func attachment(
    for _: URL,
    text _: String,
    environment _: ColorEnvironmentValues,
  ) async throws -> DisabledMarkdownImageAttachment {
    throw DisabledMarkdownImageError.loadingDisabled
  }
}

private struct DisabledMarkdownImageAttachment: Textual.Attachment {
  var description: String { "" }

  @MainActor var body: some View {
    EmptyView()
  }

  func sizeThatFits(
    _: ProposedViewSize,
    in _: TextEnvironmentValues,
  ) -> CGSize {
    .zero
  }
}

private enum DisabledMarkdownImageError: Error {
  case loadingDisabled
}
