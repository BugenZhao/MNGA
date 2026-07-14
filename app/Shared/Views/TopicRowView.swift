//
//  TopicRowView.swift
//  NGA
//
//  Created by Bugen Zhao on 6/28/21.
//

import Foundation
import SDWebImageSwiftUI
import SwiftUI

struct TopicLikeRowInnerView<S: View>: View {
  let subjectView: () -> S
  let num: UInt32
  let lastNum: UInt32?
  let names: [UserName]
  let date: UInt64
  let previewImageUrls: [String]
  let showImagePreview: Bool

  init(subjectView: @escaping () -> S, num: UInt32, lastNum: UInt32?, names: [UserName], date: UInt64, previewImageUrls: [String] = [], showImagePreview: Bool = false) {
    self.subjectView = subjectView
    self.num = num
    self.lastNum = lastNum
    self.names = names
    self.date = date
    self.previewImageUrls = previewImageUrls
    self.showImagePreview = showImagePreview
  }

  @StateObject private var prefs = PreferencesStorage.shared

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        subjectView()
        Spacer()
        RepliesNumView(num: num, lastNum: lastNum)
      }

      if showImagePreview, !previewImageUrls.isEmpty {
        let side = prefs.topicListPreviewImageHeight
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 6) {
            ForEach(Array(previewImageUrls.prefix(prefs.topicListPreviewImageCount)), id: \.self) { urlStr in
              WebImage(url: URL(string: urlStr, relativeTo: URLs.attachmentBase))
                .resizable()
                .indicator(.activity)
                .scaledToFill()
                .frame(width: side, height: side)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
          }
        }
        // The preview strip is decorative: let taps fall through to the row's
        // NavigationLink so tapping the images (or their row) opens the topic.
        .allowsHitTesting(false)
      }

      DateTimeFooterView(timestamp: date, switchable: false) {
        HStack(alignment: .center) {
          switch names.count {
          case 0:
            EmptyView()
          case 1:
            let name = names.first!
            Image(systemName: name.isAnonymous ? "theatermasks.circle" : "person")
            Text(name.display)
          default:
            Image(systemName: "person.2")
            Text(names.map(\.display).joined(separator: ", "))
          }
        }
      }
    }.padding(.vertical, 2)
  }
}

struct TopicRowView: View {
  let topic: Topic
  let useTopicPostDate: Bool
  let dimmedSubject: Bool
  let showIndicators: Bool
  let showImagePreview: Bool

  init(topic: Topic, useTopicPostDate: Bool = false, dimmedSubject: Bool = true, showIndicators: Bool = true, showImagePreview: Bool = false) {
    self.topic = topic
    self.useTopicPostDate = useTopicPostDate
    self.dimmedSubject = dimmedSubject
    self.showIndicators = showIndicators
    self.showImagePreview = showImagePreview
  }

  var shouldDim: Bool {
    dimmedSubject && !topic.id.isMNGAMockID && topic.hasRepliesNumLastVisit
  }

  @ViewBuilder
  var subject: some View {
    BlockedView(content: BlockWordsStorage.content(for: topic), revealOnTap: false) {
      TopicSubjectView(topic: topic, lineLimit: 2, showIndicators: showIndicators)
        .topicSubjectDimmed(shouldDim)
    }
  }

  var body: some View {
    TopicLikeRowInnerView(subjectView: { subject }, num: topic.repliesNum, lastNum: topic.hasRepliesNumLastVisit ? topic.repliesNumLastVisit : nil, names: [topic.authorNameCompat], date: useTopicPostDate ? topic.postDate : topic.lastPostDate, previewImageUrls: Array(topic.previewImageUrls), showImagePreview: showImagePreview)
  }
}

struct TopicRowLinkView: View {
  @Binding var topic: Topic
  let useTopicPostDate: Bool
  let dimmedSubject: Bool
  let showIndicators: Bool
  let showImagePreview: Bool

  init(topic: Binding<Topic>, useTopicPostDate: Bool = false, dimmedSubject: Bool = true, showIndicators: Bool = true, showImagePreview: Bool = false) {
    _topic = topic
    self.useTopicPostDate = useTopicPostDate
    self.dimmedSubject = dimmedSubject
    self.showIndicators = showIndicators
    self.showImagePreview = showImagePreview
  }

  @ViewBuilder
  var destination: some View {
    TopicDetailsView.build(topicBinding: $topic)
  }

  var copyableTitle: String? {
    let title = topic.subjectContentCompat.trimmingCharacters(in: .whitespacesAndNewlines)
    return title.isEmpty ? nil : title
  }

  var body: some View {
    CrossStackNavigationLinkHack(id: topic.id, destination: { destination }) {
      TopicRowView(topic: topic, useTopicPostDate: useTopicPostDate, dimmedSubject: dimmedSubject, showIndicators: showIndicators, showImagePreview: showImagePreview)
    }
    .contextMenu {
      CrossStackNavigationLinkHack(id: topic.id, destination: { destination }) {
        Label("Goto Topic", systemImage: "arrow.right")
      }
      if let copyableTitle {
        Button(action: { copyToPasteboard(copyableTitle) }) {
          Label("Copy Title", systemImage: "doc.on.doc")
        }
      }
      ShareLinksView(navigationID: topic.navID, shareTitle: topic.subject.full)
    } preview: {
      TopicDetailsView.build(topicBinding: $topic, previewMode: true)
    }
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
        $0.authorName = .with { n in n.normal = "Author" }
        $0.lastPostDate = UInt64(Date(timeIntervalSinceNow: TimeInterval(-300)).timeIntervalSince1970)
      })
    }

    AuthedPreview {
      List {
        item(0); item(20); item(50); item(150); item(250); item(550)
      }.mayGroupedListStyle()
    }
  }
}
