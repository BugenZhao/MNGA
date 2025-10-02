//
//  URLs.swift
//  MNGA
//
//  Created by Bugen Zhao on 2021/11/20.
//

import Foundation

enum URLs {
  static let attachmentBase = URL(string: "https://img.nga.178.com/attachments/")!

  static let defaultHost = "nga.178.com"
  static let hosts = [defaultHost, "bbs.nga.cn", "ngabbs.com"]

  static func base(for host: String) -> URL? {
    URL(string: "https://\(host)/")
  }

  static let defaultBase = base(for: defaultHost)!

  static var base: URL {
    URL(string: PreferencesStorage.shared.requestOption.baseURLV2) ?? defaultBase
  }

  static var login: URL {
    // iframe of URL(string: "/nuke.php?__lib=login&__act=account&login", relativeTo: base)!
    URL(string: "/nuke/account_copy.html?login", relativeTo: base)!
  }

  static var agreement: URL {
    URL(string: "/misc/agreement.html", relativeTo: base)!
  }

  static var privacy: URL {
    URL(string: "/misc/privacy.html", relativeTo: base)!
  }
}
