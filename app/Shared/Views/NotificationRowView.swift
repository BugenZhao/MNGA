//
//  NotificationRowView.swift
//  NotificationRowView
//
//  Created by Bugen Zhao on 7/17/21.
//

import Foundation
import SwiftUI

struct NotificationRowView: View {
  let noti: Notification

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Image(systemName: noti.type.icon)
        switch noti.type {
        case .shortMessage,
             .shortMessageStart:
          TopicSubjectView(topic: .with { $0.subject.content = "Short Message".localized }, showIndicators: false)
        default:
          TopicSubjectView(topic: noti.asTopic, showIndicators: false)
        }
      }.foregroundColor(noti.read ? .secondary : .primary)

      DateTimeFooterView(timestamp: noti.timestamp, switchable: false) {
        switch noti.type {
        case .replyPost,
             .replyTopic,
             .shortMessage,
             .shortMessageStart,
             .atPost,
             .atTopic:
          Image(systemName: "person")
          Text(noti.otherUser.nameDisplayCompat)
        case .vote:
          Image(systemName: "text.bubble")
          Text("Your post")
        default:
          EmptyView()
        }
        Text(noti.type.description)
      }
    }.padding(.vertical, 2)
  }
}

struct NotificationRowView_Previews: PreviewProvider {
  static var previews: some View {
    NotificationRowView(noti: .with {
      $0.type = .replyTopic
      $0.otherUser = .with { u in u.name.normal = "Bugen" }
      $0.topicSubject = .with { s in s.content = "何方道友在西安渡劫？" }
      $0.timestamp = UInt64(Date().timeIntervalSince1970 - 60)
    }).background(.primary.opacity(0.1)).padding()
  }
}
