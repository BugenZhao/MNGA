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

  struct URL {
    static let base = Foundation.URL(string: "https://ngabbs.com/")!
    static let attachmentBase = Foundation.URL(string: "https://img.nga.178.com/attachments/")!
    static let testFlight = Foundation.URL(string: "https://testflight.apple.com/join/qFDuytLt")!
    static let gitHub = Foundation.URL(string: "https://github.com/BugenZhao/MNGA")!
    static let mailTo = Foundation.URL(string: "mailto:mnga.feedback@bugenzhao.com")!
    static let login = Foundation.URL(string: "/nuke.php?__lib=login&__act=account&login", relativeTo: base)!
  }

  struct Key {
    static let groupStore = "group.com.bugenzhao.MNGA"
    static let favoriteForums = "favoriteForums"
  }

  static let postPerPage = 20
}
