//
//  TopicView.swift
//  NGA
//
//  Created by Bugen Zhao on 6/28/21.
//

import Foundation
import SwiftUI

struct TopicView: View {
  let topic: Topic

  var body: some View {
    return VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(topic.subject)
          .font(.callout)
          .lineLimit(2)
        Spacer()
        Text("\(topic.repliesNum)")
          .fontWeight(.medium)
      }

      HStack {
        HStack(alignment: .center) {
          Image(systemName: "person")
          Text(topic.authorName)
        }
        Spacer()
        Text(timeago(topic.lastPostDate))
      }
        .foregroundColor(.secondary)
        .font(.footnote)
    }
  }
}
