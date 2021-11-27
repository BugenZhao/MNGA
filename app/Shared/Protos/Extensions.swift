//
//  Extensions.swift
//  NGA
//
//  Created by Bugen Zhao on 7/3/21.
//

import Foundation
import SwiftUI

extension Subject {
  var full: String {
    self.tags.map { t in "[\(t)] " }.joined() + self.content
  }
}

extension Forum {
  var idDescription: String {
    switch self.id.id! {
    case .fid(let fid): return "#\(fid)"
    case .stid(let stid): return "##\(stid)"
    }
  }
}

extension HotTopicListRequest.DateRange {
  var description: LocalizedStringKey {
    switch self {
    case .day:
      return "Last 24 hours"
    case .week:
      return "Last week"
    case .month:
      return "Last month"
    default:
      return ""
    }
  }

  var icon: String {
    switch self {
    case .day:
      return "1.circle"
    case .week:
      return "7.circle"
    case .month:
      return "30.circle"
    default:
      return ""
    }
  }
}

extension VoteState {
  var defaultDelta: Int32 {
    switch self {
    case .none:
      return 0
    case .up:
      return 1
    case .down:
      return -1
    default:
      return 0
    }
  }
}

extension Device {
  var description: LocalizedStringKey {
    switch self {
    case .apple:
      return "iOS"
    case .android:
      return "Android"
    case .desktop:
      return "Desktop"
    default:
      return "Unknown"
    }
  }

  var icon: String {
    switch self {
    case .apple:
      return "applelogo"
    case .android:
      return "candybarphone"
    default:
      return "pc"
    }
  }
}

extension PostReplyAction {
  var title: LocalizedStringKey {
    switch self.operation {
    case .reply:
      return "Reply"
    case .quote:
      return "Quote"
    case .modify:
      return self.verbatim.modifyAppend ? "Append" : "Edit"
    case .comment:
      return "Comment"
    case .new:
      return "New Topic"
    case .UNRECOGNIZED(_):
      return ""
    }
  }
}

extension Notification {
  var asTopic: Topic {
      .with {
      $0.id = self.otherPostID.tid
      $0.subject = self.topicSubject
    }
  }
}

extension Notification.TypeEnum {
  var icon: String {
    switch self {
    case .replyPost, .replyTopic:
      return "arrowshape.turn.up.left"
    case .vote:
      return "hand.thumbsup"
    case .shortMessage:
      return "message"
    case .shortMessageStart:
      return "plus.message"
    case .unknown, .UNRECOGNIZED(_):
      return "questionmark.circle"
    }
  }

  var description: LocalizedStringKey {
    switch self {
    case .replyPost:
      return "replied to your post"
    case .replyTopic:
      return "replied to your topic"
    case .vote:
      return "received 10 more votes"
    case .shortMessage, .shortMessageStart:
      return "send you a short message"
    case .unknown, .UNRECOGNIZED(_):
      return ""
    }
  }
}

extension Post {
  var idWithAlterInfo: String {
    return self.id.debugDescription + self.alterInfo
  }
}

extension PostId: CustomStringConvertible {
  public var description: String {
    "\(self.tid), \(self.pid)"
  }
}

extension TopicListRequest.Order {
  var description: LocalizedStringKey {
    switch self {
    case .lastPost:
      return "Last Reply"
    case .postDate:
      return "Topic Post"
    default:
      return ""
    }
  }

  var latestTopicsDescription: LocalizedStringKey {
    switch self {
    case .lastPost:
      return "Latest Topics by Last Reply Date"
    case .postDate:
      return "Latest Topics by Topic Post Date"
    default:
      return ""
    }
  }

  var icon: String {
    switch self {
    case .lastPost:
      return "p.circle"
    case .postDate:
      return "t.circle"
    default:
      return ""
    }
  }
}

extension ShortMessagePostAction {
  var title: LocalizedStringKey {
    switch self.operation {
    case .reply:
      return "Reply"
    case .new, .newSingleTo:
      return "New Short Message"
    case .UNRECOGNIZED(_):
      return ""
    }
  }
}

extension User {
  var isAnonymous: Bool {
    self.name.isAnonymous
  }

  var nameDisplayCompat: String {
    let new = self.name.display
    if new.isEmpty {
      return self.nameRaw
    } else {
      return new
    }
  }
}

extension UserName {
  var isAnonymous: Bool {
    self.anonymous != ""
  }

  var display: String {
    self.anonymous.isEmpty ? self.normal : self.anonymous
  }
}

extension Topic {
  var authorNameDisplay: String {
    let new = self.authorName.display

    if new.isEmpty {
      return self.authorNameRaw
    } else {
      return new
    }
  }

  var authorNameCompat: UserName {
    let new = self.authorName.display

    if new.isEmpty {
      return .with {
        $0.normal = self.authorNameRaw
      }
    } else {
      return self.authorName
    }
  }
}

extension CacheType {
  var description: LocalizedStringKey {
    switch self {
    case .all:
      return "All"
    case .topicHistory:
      return "Topic Histories"
    case .topicDetails:
      return "Topic Cache"
    case .notification:
      return "Notifications"
    default:
      return ""
    }
  }
}

extension String {
  var isMNGAMockID: Bool {
    self.starts(with: "mnga_")
  }
}
