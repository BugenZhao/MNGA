//
//  VotesModel.swift
//  NGA
//
//  Created by Bugen Zhao on 7/12/21.
//

import Combine
import Foundation
import SwiftUI

class VotesModel: ObservableObject {
  typealias Vote = (state: VoteState, delta: Int32)

  /// Predict the resulting vote after applying `operation`, mirroring NGA's
  /// toggle semantics so optimistic updates match what the server returns:
  /// tapping the current state again clears it; switching across up/down moves
  /// by 2. Used to update the UI instantly before the network round-trip.
  static func predictVote(from current: Vote, operation: PostVoteRequest.Operation) -> Vote {
    switch (operation, current.state) {
    case (.upvote, .up): // toggle off
      return (state: .none, delta: current.delta - 1)
    case (.upvote, .down): // flip down -> up
      return (state: .up, delta: current.delta + 2)
    case (.upvote, _): // none -> up
      return (state: .up, delta: current.delta + 1)
    case (.downvote, .down): // toggle off
      return (state: .none, delta: current.delta + 1)
    case (.downvote, .up): // flip up -> down
      return (state: .down, delta: current.delta - 2)
    case (.downvote, _): // none -> down
      return (state: .down, delta: current.delta - 1)
    default: // unknown operation (e.g. UNRECOGNIZED): no change
      return current
    }
  }

  // TODO: check performance cost here
  @Published private var votes = [PostId: Vote]()

  func binding(for post: Post) -> Binding<Vote> {
    Binding(
      get: {
        self.votes[post.id] ?? (state: post.voteState, delta: 0)
      },
      set: {
        self.votes[post.id] = $0
      },
    )
  }
}
