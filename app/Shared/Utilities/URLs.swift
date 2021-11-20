//
//  URLs.swift
//  MNGA
//
//  Created by Bugen Zhao on 2021/11/20.
//

import Foundation

struct URLs {
  static let attachmentBase = URL(string: "https://img.nga.178.com/attachments/")!
  static let testFlight = URL(string: "https://testflight.apple.com/join/qFDuytLt")!
  static let gitHub = URL(string: "https://github.com/BugenZhao/MNGA")!
  static let mailTo = URL(string: "mailto:mnga.feedback@bugenzhao.com")!

  static let defaultHost = "ngabbs.com"
  static let hosts = [defaultHost, "bbs.nga.cn", "nga.178.com"]

  static func base(for host: String) -> URL? {
    URL(string: "https://\(host)/")
  }

  static let defaultBase = base(for: defaultHost)!

  static var base: URL {
    URL(string: PreferencesStorage.shared.requestOption.baseURL) ?? defaultBase
  }
  static var login: URL {
    URL(string: "/nuke.php?__lib=login&__act=account&login", relativeTo: base)!
  }
}
