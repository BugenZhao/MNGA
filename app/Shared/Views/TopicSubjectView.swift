//
//  TopicSubjectView.swift
//  NGA
//
//  Created by Bugen Zhao on 7/3/21.
//

import Flow
import Foundation
import SwiftUI

private struct TopicSubjectDimmedKey: EnvironmentKey {
  static let defaultValue: Bool = false
}

extension EnvironmentValues {
  var topicSubjectDimmed: Bool {
    get { self[TopicSubjectDimmedKey.self] }
    set { self[TopicSubjectDimmedKey.self] = newValue }
  }
}

extension View {
  func topicSubjectDimmed(_ dimmed: Bool) -> some View {
    environment(\.topicSubjectDimmed, dimmed)
  }
}

struct TopicSubjectContentInnerView: View {
  @StateObject var prefs = PreferencesStorage.shared
  @Environment(\.topicSubjectDimmed) private var topicSubjectDimmed

  let content: String
  let lineLimit: Int?
  let modifiers: [Subject.FontModifier]

  init(content: String, lineLimit: Int? = nil, modifiers: [Subject.FontModifier] = []) {
    self.content = content
    self.lineLimit = lineLimit
    self.modifiers = modifiers
  }

  func applyFontModifiers(_ text: Text, dimmed: Bool) -> Text {
    let opacity = dimmed ? 0.6 : 1
    var text = text
    for modifier in modifiers {
      switch modifier {
      case .red:
        text = text.foregroundColor(ContentCombiner.palette["red"]?.opacity(opacity))
      case .blue:
        text = text.foregroundColor(ContentCombiner.palette["blue"]?.opacity(opacity))
      case .green:
        text = text.foregroundColor(ContentCombiner.palette["green"]?.opacity(opacity))
      case .orange:
        text = text.foregroundColor(ContentCombiner.palette["orange"]?.opacity(opacity))
      case .silver:
        text = text.foregroundColor(ContentCombiner.palette["silver"]?.opacity(opacity))
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
          .if(prefs.topicListSubjectMulticolor) { applyFontModifiers($0, dimmed: topicSubjectDimmed) }
          .foregroundColor(topicSubjectDimmed ? .secondary : .primary) // applicable for subjects without color modifiers
      }
    }
    .lineLimit(lineLimit)
  }
}

struct TopicSubjectView: View {
  let topic: Topic
  let lineLimit: Int?
  let showIndicators: Bool

  init(topic: Topic, lineLimit: Int? = 2, showIndicators: Bool = false) {
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
