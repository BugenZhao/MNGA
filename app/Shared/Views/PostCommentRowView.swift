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

  @ViewBuilder
  var content: some View {
    QuoteView(fullWidth: false) {
      PostContentView(spans: Array(comment.content.spans[3...]), defaultFont: .subheadline) // ignore reply
      .equatable()
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      header
      content
    } .padding(.vertical, 2)
  }
}
