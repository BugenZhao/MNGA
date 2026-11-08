//
//  TopicPostLocator.swift
//  MNGA
//
//  Created by Codex on 2026/3/14.
//

import Foundation
import SwiftUI

@MainActor
final class TopicPostLocator: ObservableObject {
  private let topicID: String
  private var pages = [PostId: Int]()
  private var inFlight = [PostId: Task<Result<Int, LogicError>, Never>]()

  init(topic: Topic) {
    topicID = topic.id
  }

  func seed(posts: some Sequence<Post>) {
    for post in posts {
      guard post.id.tid == topicID else { continue }
      pages[post.id] = max(Int(post.atPage), 1)
    }
  }

  func cachedPage(for postId: PostId) -> Int? {
    if postId.pid == "0" {
      return 1
    }
    return pages[postId]
  }

  /// Find which page of the full topic the post is on.
  func locate(_ postId: PostId) async -> Result<Int, LogicError> {
    if let page = cachedPage(for: postId) {
      return .success(page)
    }
    if let task = inFlight[postId] {
      return await task.value
    }

    let task = Task { () -> Result<Int, LogicError> in
      let response: Result<PostLocateResponse, LogicError> = await logicCallAsync(
        .postLocate(.with { $0.pid = postId.pid }),
        errorToastModel: nil,
      )
      return response
        .map { max(Int($0.page), 1) }
        .mapError { _ in LogicError(error: "Unable to locate this post in the full topic.".localized) }
    }
    inFlight[postId] = task

    let result = await task.value
    inFlight.removeValue(forKey: postId)

    if case let .success(page) = result {
      pages[postId] = page
    }

    return result
  }
}
