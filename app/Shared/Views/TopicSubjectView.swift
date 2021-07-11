//
//  TopicSubjectView.swift
//  NGA
//
//  Created by Bugen Zhao on 7/3/21.
//

import Foundation
import SwiftUI

struct TopicSubjectView: View {
  let topic: Topic
  let lineLimit: Int?

  var body: some View {
    let contentSpan = Text(topic.subjectContent)
      .font(.headline)
      .lineLimit(lineLimit)

    if topic.tags.isEmpty {
      contentSpan
    } else {
      let tagsSpan = Text("\(topic.tags.joined(separator: " "))")
        .font(.footnote)
        .fontWeight(.medium)
        .foregroundColor(.accentColor)

      VStack(alignment: .leading) {
        tagsSpan
        Spacer().frame(height: 4)
        contentSpan
      }
    }
  }
}
