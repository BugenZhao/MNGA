//
//  URLs.swift
//  MNGA
//
//  Created by Bugen Zhao on 2021/11/20.
//

import Foundation

enum URLs {
  static let attachmentBase = URL(string: "https://img.nga.178.com/attachments/")!
  static let testFlight = URL(string: "https://testflight.apple.com/join/qFDuytLt")!
  static let gitHub = URL(string: "https://github.com/BugenZhao/MNGA")!
  static let mailTo = URL(string: "mailto:mnga.feedback@bugenzhao.com")!

  static let defaultHost = "nga.178.com"
  static let hosts = [defaultHost, "bbs.nga.cn", "ngabbs.com"]

  static let defaultMockHost = "bugenzhao.com/MNGA/api"
  static let mockHosts = [defaultMockHost, "raw.fastgit.org/BugenZhao/MNGA/gh-pages/api", "raw.githubusercontent.com/BugenZhao/MNGA/gh-pages/api"]

  static func base(for host: String) -> URL? {
    URL(string: "https://\(host)/")
  }

  static let defaultBase = base(for: defaultHost)!

  static var base: URL {
    URL(string: PreferencesStorage.shared.requestOption.baseURLV2) ?? defaultBase
  }

  static var login: URL {
    URL(string: "/nuke.php?__lib=login&__act=account&login", relativeTo: base)!
  }

  static var agreement: URL {
    URL(string: "/misc/agreement.html", relativeTo: base)!
  }

  static var privacy: URL {
    URL(string: "/misc/privacy.html", relativeTo: base)!
  }
}
