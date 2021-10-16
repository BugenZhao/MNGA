//
//  TopicRowView.swift
//  NGA
//
//  Created by Bugen Zhao on 6/28/21.
//

import Foundation
import SwiftUI

struct TopicLikeRowInnerView<S: View>: View {
  let subjectView: () -> S
  let num: UInt32
  let lastNum: UInt32?
  let name: String
  let date: UInt64

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        subjectView()
        Spacer()
        RepliesNumView(num: num, lastNum: lastNum)
      }

      HStack {
        HStack(alignment: .center) {
          Image(systemName: "person")
          Text(name)
        }
        Spacer()
        DateTimeTextView.build(timestamp: date, switchable: false)
      } .foregroundColor(.secondary)
        .font(.footnote)
    } .padding(.vertical, 4)
  }
}

struct TopicRowView: View {
  let topic: Topic
  let useTopicPostDate: Bool
  let dimmedSubject: Bool

  init(topic: Topic, useTopicPostDate: Bool = false, dimmedSubject: Bool = true) {
    self.topic = topic
    self.useTopicPostDate = useTopicPostDate
    self.dimmedSubject = dimmedSubject
  }

  @ViewBuilder
  var subject: some View {
    BlockedView(content: topic.subject.full, revealOnTap: false) {
      TopicSubjectView(topic: topic, lineLimit: 2, showIndicators: true)
        .foregroundColor(dimmedSubject && topic.hasRepliesNumLastVisit ? .secondary : nil)
    }
  }

  var body: some View {
    TopicLikeRowInnerView(subjectView: { subject }, num: topic.repliesNum, lastNum: topic.hasRepliesNumLastVisit ? topic.repliesNumLastVisit : nil, name: topic.authorName, date: useTopicPostDate ? topic.postDate : topic.lastPostDate)
  }
}

struct TopicView_Previews: PreviewProvider {
  static var previews: some View {
    let item = { (n: UInt32) in
      TopicRowView(topic: .with {
        $0.subject = .with { s in
          s.tags = ["不懂就问", "树洞"]
          s.content = "很长的标题很长的标题很长的标题很长的标题很长的标题很长的标题很长的标题"
        }
        $0.repliesNum = n
        $0.authorName = "Author"
        $0.lastPostDate = UInt64(Date(timeIntervalSinceNow: TimeInterval(-300)).timeIntervalSince1970)
      })
    }

    AuthedPreview {
      List {
        item(0); item(20); item(50); item(150); item(250); item(550);
      } .mayGroupedListStyle()
    }
  }
}
