//
//  PlusFeature.swift
//  MNGA
//
//  Created by Bugen Zhao on 2025/10/11.
//

// The order of features will be displayed in "All Plus Features" page.
enum PlusFeature: CaseIterable {
  case customAppearance
  case multiAccount
  case topicHistory
  case followedActivity
  case multiFavorite
  case authorOnly
  case jump
  case resumeProgress
  case blockContents
  case syncForums
  case anonymous
  case newTopic
  case hotTopic
  case shortMessage

  var name: String {
    switch self {
    case .anonymous:
      "Anonymous"
    case .newTopic:
      "New Topic"
    case .hotTopic:
      "Hot Topics"
    case .shortMessage:
      "Short Messages"
    case .topicHistory:
      "History"
    case .followedActivity:
      "Followed Activity"
    case .authorOnly:
      "Author Only"
    case .jump:
      "Jump"
    case .multiAccount:
      "Multiple Accounts"
    case .customAppearance:
      "Custom Appearance"
    case .blockContents:
      "Block Contents"
    case .multiFavorite:
      "Multiple Favorite Folders"
    case .resumeProgress:
      "Resume Reading Progress"
    case .syncForums:
      "Sync Favorite Forums"
    }
  }

  var description: String {
    switch self {
    case .anonymous:
      "Post, quote, reply, comment, and create new topics anonymously."
    case .newTopic:
      "Create new topics in all forums."
    case .hotTopic:
      "View hot topics from the past 24 hours, week, or month."
    case .shortMessage:
      "Send and receive short messages with other users."
    case .topicHistory:
      "View your footprint of topics you have explored."
    case .followedActivity:
      "View activity from the users you follow."
    case .authorOnly:
      "Check posts and replies from a specific author in a topic."
    case .jump:
      "Jump to arbitrary floor or page in a topic."
    case .multiAccount:
      "Log in and switch between multiple accounts."
    case .customAppearance:
      "Full access to customizing the appearance of MNGA."
    case .blockContents:
      "Block contents from specific users, or with specific keywords."
    case .multiFavorite:
      "Organize favorite topics into multiple folders."
    case .resumeProgress:
      "Resume reading progress from where you left off."
    case .syncForums:
      "Sync favorite forums across devices."
    }
  }

  var icon: String {
    switch self {
    case .anonymous:
      "theatermasks"
    case .newTopic:
      "square.and.pencil"
    case .hotTopic:
      "flame"
    case .shortMessage:
      "message"
    case .topicHistory:
      "clock"
    case .followedActivity:
      "sparkles"
    case .authorOnly:
      "person.fill"
    case .jump:
      "arrow.up.arrow.down"
    case .multiAccount:
      "person.2"
    case .customAppearance:
      "paintbrush"
    case .blockContents:
      "hand.raised"
    case .multiFavorite:
      "bookmark"
    case .resumeProgress:
      "clock.arrow.circlepath"
    case .syncForums:
      "icloud"
    }
  }
}
