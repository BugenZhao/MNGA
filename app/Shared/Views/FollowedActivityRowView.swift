//
//  FollowedActivityRowView.swift
//  MNGA
//
//  Created by Bugen Zhao on 2025/12/18.
//

import Foundation
import SwiftUI

struct FollowedActivityRowView: View {
  let activity: Activity

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Image(systemName: activity.type.icon)
        TopicSubjectView(topic: activity.topic)
      }
      .topicSubjectDimmed(activity.topic.read)
      .foregroundColor(activity.topic.read ? .secondary : .primary)

      HStack {
        HStack(alignment: .center) {
          Image(systemName: "person")
          Text(activity.actor.nameDisplayCompat)
        }
        Text(activity.type.description)
        Spacer()
        DateTimeTextView.build(timestamp: activity.timestamp, switchable: false)
      }
      .foregroundColor(.secondary)
      .font(.footnote)
    }
    .padding(.vertical, 2)
  }
}

struct FollowedActivityRowView_Previews: PreviewProvider {
  static var previews: some View {
    FollowedActivityRowView(activity: .with {
      $0.id = "1"
      $0.type = .postTopic
      $0.actor = .with { $0.name.normal = "Bugen" }
      $0.topic = .with {
        $0.id = "123"
        $0.subject = .with { $0.content = "Test Topic" }
      }
      $0.postID = .with {
        $0.tid = "123"
        $0.pid = "0"
      }
      $0.timestamp = UInt64(Date().timeIntervalSince1970 - 60)
    })
    .background(.primary.opacity(0.1))
    .padding()
  }
}
