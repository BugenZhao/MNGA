//
//  PostCommentRowView.swift
//  PostCommentRowView
//
//  Created by Bugen Zhao on 7/18/21.
//

import Foundation
import SwiftUI

struct PostCommentRowView: View {
  let comment: Post

  @ViewBuilder
  var header: some View {
    HStack {
      PostRowUserView(post: comment, compact: true)
        .equatable()
      Spacer()
      DateTimeTextView.build(timestamp: comment.postDate)
        .foregroundColor(.secondary)
        .font(.footnote)
    }
  }

  var realSpans: ArraySlice<Span> {
    let spans = comment.content.spans
    if spans.count > 3 {
      return spans.dropFirst(3) // ignore reply
    } else {
      return spans[...]
    }
  }

  @ViewBuilder
  var content: some View {
    QuoteView(fullWidth: false) {
      PostContentView(spans: realSpans, defaultFont: .subheadline, initialInQuote: true)
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      header
      content
    } .padding(.vertical, 2)
  }
}
