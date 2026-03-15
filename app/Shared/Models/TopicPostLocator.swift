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
  struct Location: Equatable {
    let floor: Int
    let page: Int
  }

  private let topicID: String
  private let fav: String?
  private let localCache: Bool
  private var locations = [PostId: Location]()
  private var inFlight = [PostId: Task<Result<Location, LogicError>, Never>]()

  init(topic: Topic, localCache: Bool = false) {
    topicID = topic.id
    fav = topic.hasFav ? topic.fav : nil
    self.localCache = localCache
  }

  func seed(posts: some Sequence<Post>) {
    for post in posts {
      guard post.id.tid == topicID else { continue }
      let page = max(Int(post.atPage), 1)
      locations[post.id] = .init(floor: Int(post.floor), page: page)
    }
  }

  func cachedLocation(for postId: PostId) -> Location? {
    if postId.pid == "0" {
      return .init(floor: 0, page: 1)
    }
    return locations[postId]
  }

  func locate(_ postId: PostId) async -> Result<Location, LogicError> {
    if let location = cachedLocation(for: postId) {
      return .success(location)
    }
    if let task = inFlight[postId] {
      return await task.value
    }

    let task = Task { [weak self] () -> Result<Location, LogicError> in
      guard let self else {
        return .failure(LogicError(error: "Unable to locate this post in the full topic."))
      }
      return await scanLocation(for: postId)
    }
    inFlight[postId] = task

    let result = await task.value
    inFlight.removeValue(forKey: postId)

    if case let .success(location) = result {
      locations[postId] = location
    }

    return result
  }

  private func scanLocation(for postId: PostId) async -> Result<Location, LogicError> {
    var page = 1
    var totalPages: Int?

    while totalPages == nil || page <= totalPages! {
      let response: Result<TopicDetailsResponse, LogicError> = await logicCallAsync(
        buildRequest(page: page),
        errorToastModel: nil,
      )

      switch response {
      case let .success(response):
        seed(posts: response.replies)

        if let location = locations[postId] {
          return .success(location)
        }

        totalPages = max(Int(response.pages), 1)
        if response.replies.isEmpty {
          break
        }
        page += 1
      case let .failure(error):
        return .failure(error)
      }
    }

    return .failure(LogicError(error: "Unable to locate this post in the full topic."))
  }

  private func buildRequest(page: Int) -> AsyncRequest.OneOf_Value {
    .topicDetails(TopicDetailsRequest.with {
      $0.webApiStrategy = PreferencesStorage.shared.topicDetailsWebApiStrategy
      $0.topicID = topicID
      if let fav {
        $0.fav = fav
      }
      $0.localCache = localCache
      $0.page = UInt32(page)
    })
  }
}
