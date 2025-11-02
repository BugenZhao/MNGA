//
//  TopicPostRowView.swift
//  MNGA
//
//  Created by Bugen Zhao on 2021/9/27.
//

import Foundation
import SwiftUI

struct TopicPostRowView: View {
  let topic: Topic
  let post: LightPost

  var cleanSpans: [Span] {
    let spans = post.content.spans.filter {
      let isQuote = $0.tagged.tag == "quote"
      let isReply = $0.tagged.tag == "b" && $0.tagged.spans.first?.plain.text.starts(with: "Reply to") == true
      return !(isQuote || isReply)
    }
    if spans.isEmpty {
      return [
        Span.with { s in
          s.plain = .with { $0.text = "..." }
        },
      ]
    } else {
      return spans
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      TopicSubjectView(topic: topic, lineLimit: 2)

      QuoteView(fullWidth: false) {
        PostContentView(spans: cleanSpans, id: post.id, postDate: post.postDate, authorId: post.authorID, initialInQuote: true)
          .lineLimit(5)
      }

      HStack {
        Spacer()
        DateTimeTextView.build(timestamp: post.postDate, switchable: false)
      }.foregroundColor(.secondary)
        .font(.footnote)
    }.fixedSize(horizontal: false, vertical: true)
      .padding(.vertical, 2)
  }
}
