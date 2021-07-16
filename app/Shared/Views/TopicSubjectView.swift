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
    } .font(.footnote, weight: .bold)
  }

  var showTagBar: Bool {
    !topic.tags.isEmpty || topic.hasParentForum || (showIndicators && (topic.isFavored))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      if showTagBar {
        HStack(alignment: .bottom) {
          if showIndicators {
            indicators
          }
          if topic.hasParentForum {
            Text(topic.parentForum.name)
              .fontWeight(.heavy)
          }
          ForEach(topic.tags, id: \.self) { tag in
            Text(tag)
          }
        } .font(.footnote)
          .foregroundColor(.accentColor)
          .lineLimit(1)
      }

      Text(topic.subjectContent)
        .font(.headline)
        .lineLimit(lineLimit)
    }
  }
}
