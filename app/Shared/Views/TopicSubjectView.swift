//
//  TopicSubjectView.swift
//  NGA
//
//  Created by Bugen Zhao on 7/3/21.
//

import Flow
import Foundation
import SwiftUI

struct TopicSubjectContentInnerView: View {
  let content: String
  let lineLimit: Int?

  var body: some View {
    Text(content)
      .font(.headline)
      .lineLimit(lineLimit)
  }
}

struct TopicSubjectView: View {
  let topic: Topic
  let lineLimit: Int?
  let showIndicators: Bool

  init(topic: Topic, lineLimit: Int? = nil, showIndicators: Bool = false) {
    self.topic = topic
    self.lineLimit = lineLimit
    self.showIndicators = showIndicators
  }

  @ViewBuilder
  var indicators: some View {
    HStack(spacing: 2) {
      if topic.isFavored {
        Image(systemName: "bookmark")
      }
    }.font(.footnote.bold())
  }

  var tags: [String] {
    topic.tagsCompat
  }

  var content: String {
    topic.subjectContentCompat
  }

  var showTagBar: Bool {
    !tags.isEmpty || topic.hasParentForum || (showIndicators && (topic.isFavored))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      if showTagBar {
        HFlow(alignment: .bottom) {
          if showIndicators {
            indicators
          }
          if topic.hasParentForum {
            Text(topic.parentForum.name)
              .fontWeight(.heavy)
          }
          ForEach(tags, id: \.self) { tag in
            Text(tag)
          }
        }.font(.footnote)
          .foregroundColor(.accentColor)
          .lineLimit(1)
      }

      TopicSubjectContentInnerView(content: content, lineLimit: lineLimit)
    }
  }
}
