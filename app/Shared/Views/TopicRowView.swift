//
//  TopicRowView.swift
//  NGA
//
//  Created by Bugen Zhao on 6/28/21.
//

import Foundation
import SwiftUI

struct RepliesNumView: View {
  let num: UInt32
  let lastNum: UInt32?

  var fontStyle: (Font?, Color?) {
    switch num {
    case 0:
      return (.subheadline.weight(.regular), .accentColor.opacity(0.0))
    case 1..<40:
      return (.callout.weight(.medium), .accentColor.opacity(0.8))
    case 40..<100:
      return (.callout.weight(.semibold), .accentColor.opacity(0.9))
    case 100..<200:
      return (.body.weight(.semibold), .accentColor)
    case 200..<500:
      return (.body.weight(.bold), .accentColor)
    case 500...:
      return (.body.weight(.heavy), .accentColor)
    default:
      return (nil, nil)
    }
  }

  var text: some View {
    let (font, color) = fontStyle
    var text = Text("\(num)").font(font)
    if let lastNum = lastNum, num > lastNum {
      text = text + Text("(+\(num - lastNum))").font(.footnote)
    }
    return text.foregroundColor(color)
  }

  var body: some View {
    text
  }
}

struct TopicRowView: View {
  let topic: Topic
  let dimmedSubject: Bool
  
  init(topic: Topic, dimmedSubject: Bool = true) {
    self.topic = topic
    self.dimmedSubject = dimmedSubject
  }
  
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        TopicSubjectView(topic: topic, lineLimit: 2, showIndicators: true)
          .foregroundColor(dimmedSubject && topic.hasRepliesNumLastVisit ? .secondary : nil)
        Spacer()
        RepliesNumView(num: topic.repliesNum, lastNum: topic.hasRepliesNumLastVisit ? topic.repliesNumLastVisit : nil)
      }

      HStack {
        HStack(alignment: .center) {
          Image(systemName: "person")
          Text(topic.authorName)
        }
        Spacer()
        DateTimeTextView.build(timestamp: topic.lastPostDate, switchable: false)
      } .foregroundColor(.secondary)
        .font(.footnote)
    } .padding(.vertical, 4)
  }
}

struct TopicView_Previews: PreviewProvider {
  static var previews: some View {
    let item = { (n: UInt32) in
      TopicRowView(topic: .with {
        $0.tags = ["不懂就问", "树洞"]
        $0.subjectContent = "很长的标题很长的标题很长的标题很长的标题很长的标题很长的标题很长的标题"
        $0.repliesNum = n
        $0.authorName = "Author"
        $0.lastPostDate = UInt64(Date(timeIntervalSinceNow: TimeInterval(-300)).timeIntervalSince1970)
      })
    }

    AuthedPreview {
      List {
        item(0); item(20); item(50); item(150); item(250); item(550);
      }
      #if os(iOS)
        .listStyle(GroupedListStyle())
      #endif
    }
  }
}
