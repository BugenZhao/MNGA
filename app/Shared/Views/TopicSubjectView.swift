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
    VStack(alignment: .leading, spacing: 4) {
      if !topic.tags.isEmpty || topic.hasParentForum {
        HStack(alignment: .bottom) {
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
