//
//  Constants.swift
//  NGA
//
//  Created by Bugen Zhao on 7/12/21.
//

import Foundation

enum Constants {
  enum Activity {
    private static let base = "com.bugenzhao.NGA"

    static let openTopic = "\(base).openTopic"
    static let openForum = "\(base).openForum"
  }

  enum MNGA {
    static let scheme = "mnga"
    static let topicBase = "\(scheme)://topic/"
    static let postBase = "\(scheme)://post/"
    static let forumFBase = "\(scheme)://forum/f/"
    static let forumSTBase = "\(scheme)://forum/st/"
    static let userBase = "\(scheme)://user/"
  }

  enum Key {
    /// The entitlements grant the app group named after the bundle ID, so
    /// derive it instead of hardcoding a fixed one: a build with a custom
    /// bundle ID is not entitled to the hardcoded group and would silently
    /// fall back to a container-local store.
    static let groupStore = "group.\(Bundle.main.bundleIdentifier ?? "com.bugenzhao.MNGA")"
    static let favoriteForums = "favoriteForums"
  }

  enum Plus {
    static let ids = [unlockID, trialID]
    static let unlockID = "mnga.unlock"
    static let trialID = "mnga.unlock.trial14"
  }

  static let postPerPage = 20
}
