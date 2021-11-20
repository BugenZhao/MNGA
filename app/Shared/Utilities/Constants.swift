//
//  Constants.swift
//  NGA
//
//  Created by Bugen Zhao on 7/12/21.
//

import Foundation

struct Constants {
  struct Activity {
    private static let base = "com.bugenzhao.NGA"

    static let openTopic = "\(base).openTopic"
    static let openForum = "\(base).openForum"
  }

  struct MNGA {
    static let scheme = "mnga"
    static let topicBase = "\(scheme)://topic/"
    static let forumFBase = "\(scheme)://forum/f/"
    static let forumSTBase = "\(scheme)://forum/st/"
  }

  struct Key {
    static let groupStore = "group.com.bugenzhao.MNGA"
    static let favoriteForums = "favoriteForums"
  }

  static let postPerPage = 20
}
