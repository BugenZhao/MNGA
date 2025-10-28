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
    case let .fid(fid): "#\(fid)"
    case let .stid(stid): "##\(stid)"
    }
  }
}

extension HotTopicListRequest.DateRange {
  var description: LocalizedStringKey {
    switch self {
    case .day:
      "Last 24 hours"
    case .week:
      "Last week"
    case .month:
      "Last month"
    default:
      ""
    }
  }

  var icon: String {
    switch self {
    case .day:
      "1.circle"
    case .week:
      "7.circle"
    case .month:
      "30.circle"
    default:
      ""
    }
  }
}

extension VoteState {
  var defaultDelta: Int32 {
    switch self {
    case .none:
      0
    case .up:
      1
    case .down:
      -1
    default:
      0
    }
  }
}

extension Device {
  var description: LocalizedStringKey {
    switch self {
    case .apple:
      "iOS"
    case .android:
      "Android"
    case .desktop:
      "Desktop"
    case .windowsPhone:
      "Windows Phone"
    case .custom:
      "Custom"
    default:
      "Unknown"
    }
  }

  var icon: String {
    switch self {
    case .apple:
      "applelogo"
    case .android:
      "candybarphone"
    case .desktop:
      "pc"
    case .windowsPhone:
      "flipphone"
    case .custom:
      "questionmark.square.dashed"
    default:
      "pc"
    }
  }
}

extension PostReplyAction {
  var title: LocalizedStringKey {
    switch operation {
    case .reply:
      "Reply"
    case .quote:
      "Quote"
    case .modify:
      verbatim.modifyAppend ? "Append" : "Edit"
    case .comment:
      "Comment"
    case .new:
      "New Topic"
    case .report:
      "Report"
    case .UNRECOGNIZED:
      ""
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
      "arrowshape.turn.up.left"
    case .vote:
      "hand.thumbsup"
    case .shortMessage:
      "message"
    case .shortMessageStart:
      "plus.message"
    case .unknown, .UNRECOGNIZED:
      "questionmark.circle"
    }
  }

  var description: LocalizedStringKey {
    switch self {
    case .replyPost:
      "replied to your post"
    case .replyTopic:
      "replied to your topic"
    case .vote:
      "received 10 more votes"
    case .shortMessage, .shortMessageStart:
      "send you a short message"
    case .unknown, .UNRECOGNIZED:
      ""
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
      "Latest Replies"
    case .postDate:
      "Latest Topics"
    default:
      ""
    }
  }

  var latestTopicsDescription: LocalizedStringKey {
    switch self {
    case .lastPost:
      "Latest Topics by Last Reply Date"
    case .postDate:
      "Latest Topics by Topic Post Date"
    default:
      ""
    }
  }

  var icon: String {
    switch self {
    case .lastPost:
      "p.circle"
    case .postDate:
      "t.circle"
    default:
      ""
    }
  }
}

extension ShortMessagePostAction {
  var title: LocalizedStringKey {
    switch operation {
    case .reply:
      "Reply"
    case .new, .newSingleTo:
      "New Short Message"
    case .UNRECOGNIZED:
      ""
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

  // for compatibility
  var subjectContentCompat: String {
    subject.content.isEmpty ? subjectContent : subject.content
  }

  var tagsCompat: [String] {
    subject.tags.isEmpty ? tags : subject.tags
  }
}

extension CacheType {
  var description: LocalizedStringKey {
    switch self {
    case .all:
      "All"
    case .topicHistory:
      "Topic Histories"
    case .topicDetails:
      "Topic Cache"
    case .notification:
      "Notifications"
    default:
      ""
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
    with { $0.word = "\(userPrefix)\(user.display)" }
  }

  var userName: String? {
    if word.starts(with: Self.userPrefix) {
      return String(word.dropFirst(Self.userPrefix.count))
    } else {
      return nil
    }
  }
}

extension TopicDetailsResponse {
  var cacheLoadedMessage: String? {
    if hasLocalReason {
      return localReason
    } else {
      return nil
    }
  }
}
