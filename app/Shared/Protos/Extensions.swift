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

extension Post.Device {
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

extension Notification.TypeEnum {
  var icon: String {
    switch self {
    case .replyPost, .replyTopic:
      return "arrowshape.turn.up.left"
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
