//
//  URLs.swift
//  MNGA
//
//  Created by Bugen Zhao on 2021/11/20.
//

import Foundation

enum URLs {
  static let attachmentBase = URL(string: "https://img.nga.cn/attachments/")!

  private static let legacyImageDomainSuffixes = [".nga.178.com", ".ngacn.cc", ".ngabbs.com"]

  static func resourceURL(_ value: String, relativeTo base: URL? = nil) -> URL? {
    guard let url = URL(string: value, relativeTo: base)?.absoluteURL,
          var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
          let host = components.host?.lowercased()
    else { return nil }

    let hostParts = host.split(separator: ".", maxSplits: 1).map(String.init)
    guard hostParts.count == 2,
          hostParts[0].hasPrefix("img"),
          hostParts[0].dropFirst(3).allSatisfy(\.isNumber),
          legacyImageDomainSuffixes.contains(where: host.hasSuffix)
    else { return url }

    components.scheme = "https"
    components.host = url.path.hasPrefix("/ngabbs/") ? "img4.nga.cn" : "img.nga.cn"
    return components.url ?? url
  }

  static func attachmentURL(_ value: String) -> URL? {
    resourceURL(value, relativeTo: attachmentBase)
  }

  static let defaultHost = "bbs.nga.cn"
  static let hosts = [defaultHost, "ngabbs.com", "bbs.ngacn.cc"]

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
