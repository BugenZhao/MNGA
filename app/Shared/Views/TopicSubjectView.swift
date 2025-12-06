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
  @StateObject var prefs = PreferencesStorage.shared

  let content: String
  let lineLimit: Int?
  let modifiers: [Subject.FontModifier]

  init(content: String, lineLimit: Int? = nil, modifiers: [Subject.FontModifier] = []) {
    self.content = content
    self.lineLimit = lineLimit
    self.modifiers = modifiers
  }

  func applyFontModifiers(_ text: Text) -> Text {
    var text = text
    for modifier in modifiers {
      switch modifier {
      case .red:
        text = text.foregroundColor(ContentCombiner.palette["red"])
      case .blue:
        text = text.foregroundColor(ContentCombiner.palette["blue"])
      case .green:
        text = text.foregroundColor(ContentCombiner.palette["green"])
      case .orange:
        text = text.foregroundColor(ContentCombiner.palette["orange"])
      case .silver:
        text = text.foregroundColor(ContentCombiner.palette["silver"])
      case .semibold:
        text = text.fontWeight(.semibold)
      case .bold:
        text = text.fontWeight(.bold)
      case .italic:
        text = text.italic()
      case .underline:
        text = text.underline()
      default:
        continue
      }
    }

    return text
  }

  var body: some View {
    Group {
      if content.isEmpty {
        Text("Untitled")
          .font(.headline.weight(.medium).italic())
          .foregroundColor(.secondary)
      } else {
        Text(content)
          .font(.headline.weight(.medium)) // headline is semibold by default
          .if(prefs.topicListSubjectMulticolor) { applyFontModifiers($0) }
      }
    }
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
              .fontWeight(.bold)
          }
          ForEach(tags, id: \.self) { tag in
            Text(tag)
          }
        }.font(.footnote)
          .foregroundColor(.accentColor)
          .lineLimit(1)
      }

      TopicSubjectContentInnerView(
        content: content,
        lineLimit: lineLimit,
        modifiers: topic.subject.fontModifiers
      )
    }
  }
}
