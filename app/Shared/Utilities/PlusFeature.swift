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
  case multiFavorite
  case authorOnly
  case jump
  case resumeProgress
  case userProfile
  case anonymous
  case blockContents
  case comment
  case newTopic
  case hotTopic
  case shortMessage

  var name: String {
    switch self {
    case .comment:
      "Comment"
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
    case .authorOnly:
      "Author Only"
    case .jump:
      "Jump"
    case .multiAccount:
      "Multiple Accounts"
    case .userProfile:
      "User Profile"
    case .customAppearance:
      "Custom Appearance"
    case .blockContents:
      "Block Contents"
    case .multiFavorite:
      "Multiple Favorite Folders"
    case .resumeProgress:
      "Resume Reading Progress"
    }
  }

  var description: String {
    switch self {
    case .comment:
      "Comment on posts in all topics."
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
    case .authorOnly:
      "Check posts and replies from a specific author in a topic."
    case .jump:
      "Jump to arbitrary floor or page in a topic."
    case .multiAccount:
      "Log in and switch between multiple accounts."
    case .userProfile:
      "View user profiles, with their posts and replies."
    case .customAppearance:
      "Full access to customizing the appearance of MNGA."
    case .blockContents:
      "Block contents from specific users, or with specific keywords."
    case .multiFavorite:
      "Organize favorite topics into multiple folders."
    case .resumeProgress:
      "Resume reading progress from where you left off."
    }
  }

  var icon: String {
    switch self {
    case .comment:
      "tag"
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
    case .authorOnly:
      "person.fill"
    case .jump:
      "arrow.up.arrow.down"
    case .multiAccount:
      "person.2"
    case .userProfile:
      "person.text.rectangle"
    case .customAppearance:
      "paintbrush"
    case .blockContents:
      "hand.raised"
    case .multiFavorite:
      "bookmark"
    case .resumeProgress:
      "clock.arrow.circlepath"
    }
  }
}
