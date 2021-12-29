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
    tags.map { t in "[\(t)] " }.joined() + content
  }
}

extension Forum {
  var idDescription: String {
    switch id.id! {
    case let .fid(fid): return "#\(fid)"
    case let .stid(stid): return "##\(stid)"
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
    switch operation {
    case .reply:
      return "Reply"
    case .quote:
      return "Quote"
    case .modify:
      return verbatim.modifyAppend ? "Append" : "Edit"
    case .comment:
      return "Comment"
    case .new:
      return "New Topic"
    case .report:
      return "Report"
    case .UNRECOGNIZED:
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
    case .unknown, .UNRECOGNIZED:
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
    case .unknown, .UNRECOGNIZED:
      return ""
    }
  }
}

extension Post {
  var idWithAlterInfo: String {
    id.debugDescription + alterInfo
  }
}

extension PostId: CustomStringConvertible {
  public var description: String {
    "\(tid), \(pid)"
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
    switch operation {
    case .reply:
      return "Reply"
    case .new, .newSingleTo:
      return "New Short Message"
    case .UNRECOGNIZED:
      return ""
    }
  }
}

extension User {
  var isAnonymous: Bool {
    name.isAnonymous
  }

  var nameDisplayCompat: String {
    let new = name.display
    if new.isEmpty {
      return nameRaw
    } else {
      return new
    }
  }
}

extension UserName {
  var isAnonymous: Bool {
    anonymous != ""
  }

  var display: String {
    anonymous.isEmpty ? normal : anonymous
  }
}

extension Topic {
  var authorNameDisplay: String {
    let new = authorName.display

    if new.isEmpty {
      return authorNameRaw
    } else {
      return new
    }
  }

  var authorNameCompat: UserName {
    let new = authorName.display

    if new.isEmpty {
      return .with {
        $0.normal = self.authorNameRaw
      }
    } else {
      return authorName
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
    starts(with: "mnga_")
  }
}

extension PostId {
  static var dummy: Self {
    PostId.with {
      $0.tid = "dummy"
      $0.pid = "dummy"
    }
  }
}

extension Post {
  static var dummy: Self {
    let contentRes: ContentParseResponse? = try? logicCall(.contentParse(.with { r in
      r.raw = "This is a post.".localized
//      r.raw += "<br/>"
//      r.raw += "[collapse]\("Collapsed here.".localized)[/collapse]"
    }))
    let commentRes: ContentParseResponse? = try? logicCall(.contentParse(.with { r in r.raw = "This is a comment.".localized }))

    let recentDate = UInt64(Date().timeIntervalSince1970 - 10 * 60)
    let oldDate = UInt64(1_609_502_400)

    return Post.with {
      $0.id = .dummy
      $0.score = 233
      $0.authorID = User.dummyID
      $0.content = contentRes?.content ?? .init()
      $0.voteState = .up
      $0.postDate = oldDate
      $0.floor = 42

      $0.comments = [Post.with { c in
        c.id = .dummy
        c.authorID = User.dummyID
        c.content = commentRes?.content ?? .init()
        c.postDate = recentDate
      }]
    }
  }
}

extension User {
  static var dummyID: String {
    "dummy"
  }

  static var dummy: Self {
    let signatureRes: ContentParseResponse? = try? logicCall(.contentParse(.with { r in r.raw = "This is a signature.".localized }))

    return User.with {
      $0.id = Self.dummyID
      $0.name.normal = "Dummy User".localized
      $0.fame = 25
      $0.postNum = 2333
      $0.regDate = 1_609_502_400
      $0.signature = signatureRes?.content ?? .init()
      $0.avatarURL = "https://img.nga.178.com/avatars/2002/03a/000/000/58_0.jpg"
    }
  }
}

extension BlockWord {
  static let userPrefix = "User: "

  static func fromUser(_ user: UserName) -> Self {
    Self.with { $0.word = "\(userPrefix)\(user.display)" }
  }

  var userName: String? {
    if word.starts(with: Self.userPrefix) {
      return String(word.dropFirst(Self.userPrefix.count))
    } else {
      return nil
    }
  }
}
