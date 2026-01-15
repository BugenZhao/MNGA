//
//  QuotedPostResolver.swift
//  MNGA
//
//  Created by Codex on 2026/1/14.
//

import Foundation
import Combine

final class QuotedPostResolver: ObservableObject {
  @Published private(set) var posts = [PostId: Post]()
  @Published private(set) var failed = Set<PostId>()

  private var prefs = PreferencesStorage.shared
  var localPostProvider: ((PostId) -> Post?)?

  private var inFlight = Set<PostId>()

  func seed(posts: some Sequence<Post>) {
    for post in posts {
      self.posts[post.id] = post
      failed.remove(post.id)
    }
  }

  func post(for id: PostId) -> Post? {
    if let post = posts[id] {
      return post
    }
    if let post = localPostProvider?(id) {
      posts[id] = post
      failed.remove(id)
      return post
    }
    return nil
  }

  func load(id: PostId) {
    if posts[id] != nil || failed.contains(id) || inFlight.contains(id) {
      return
    }
    if let post = localPostProvider?(id) {
      posts[id] = post
      failed.remove(id)
      return
    }

    inFlight.insert(id)
    logicCallAsync(.topicDetails(.with {
      $0.webApiStrategy = prefs.topicDetailsWebApiStrategy
      $0.topicID = id.tid
      $0.postID = id.pid
    })) { (response: TopicDetailsResponse) in
      DispatchQueue.main.async {
        self.inFlight.remove(id)
        if let post = response.replies.first {
          self.posts[id] = post
          self.failed.remove(id)
        } else {
          self.failed.insert(id)
        }
      }
    }
  }

  func resetFailures() {
    failed.removeAll()
  }
}
