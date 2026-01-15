//
//  InlineQuotedPostView.swift
//  MNGA
//
//  Created by Codex on 2026/1/14.
//

import Foundation
import SwiftUI
import SwiftUIX

struct InlineQuotedPostView: View {
  let postId: PostId
  let uid: String
  let nameHint: String?
  let sourcePostId: PostId?
  let defaultFont: Font
  let defaultColor: Color

  @EnvironmentObject<TopicDetailsActionModel>.Optional private var actionModel
  @EnvironmentObject<QuotedPostResolver>.Optional private var resolverEnv

  @StateObject private var localResolver = QuotedPostResolver()

  private var resolver: QuotedPostResolver {
    resolverEnv ?? localResolver
  }

  private var showChainAction: (() -> Void)? {
    guard let actionModel, let sourcePostId else { return nil }
    return { actionModel.showReplyChain(from: sourcePostId) }
  }

  private func quotedPostContent(_ post: Post) -> some View {
    let combiner = ContentCombiner(
      actionModel: actionModel,
      id: post.id,
      postDate: post.postDate,
      defaultFont: defaultFont,
      defaultColor: defaultColor
    )
    combiner.inQuote = true
    combiner.inReplyQuote = true
    combiner.visit(spans: post.content.spans)
    return combiner.buildView()
  }

  @ViewBuilder
  private var bodyContent: some View {
    if let post = resolver.post(for: postId) {
      quotedPostContent(post)
    } else if resolver.failed.contains(postId) {
      EmptyRowView(title: "Reply not found. It may have been deleted.")
    } else {
      ProgressView()
        .controlSize(.small)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  var body: some View {
    QuoteView(fullWidth: true) {
      VStack(alignment: .leading, spacing: 8) {
        QuoteUserView(uid: uid, nameHint: nameHint, action: showChainAction)
        bodyContent
      }
    }
    .lineLimit(showChainAction == nil ? nil : 5)
    .onAppear { resolver.load(id: postId) }
    #if DEBUG
      .overlay(alignment: .topTrailing) {
        Text("INL")
          .font(.caption2.monospaced().weight(.semibold))
          .foregroundColor(.secondary.opacity(0.35))
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(Capsule().fill(Color.secondary.opacity(0.08)))
          .padding(6)
          .allowsHitTesting(false)
      }
    #endif
  }
}
